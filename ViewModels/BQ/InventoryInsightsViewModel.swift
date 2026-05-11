import SwiftUI
import Combine



@MainActor
final class InventoryInsightsViewModel: ObservableObject {

    // BQ3 state
    @Published private(set) var restockDashboard: RestockCyclesDashboard?
    @Published private(set) var isLoadingRestock = false

    // BQ4 state
    @Published private(set) var expirationDashboard: ExpirationInsightsDashboard?
    @Published private(set) var isLoadingExpiration = false

    @Published var errorMessage: String?

    private let cycleStore = RestockCycleStore.shared
    private let cycleAnalyzer = RestockCycleAnalyzer.shared
    private let expirationAnalyzer = ExpirationInsightsAnalyzer.shared

    // FIX: Caching — caché en `NSCache` con `countLimit` y `totalCostLimit`
    // explícitos en vez de un dictionary manual con TTL ad-hoc. Beneficios:
    //   • Eviction automática bajo memory warnings del OS
    //   • Thread-safe nativo (no necesitamos coordinar mutaciones)
    //   • `countLimit: 4` cubre las 2 BQ dashboards × 2 variantes (force/no-force)
    //     sin desperdiciar memoria
    //   • `totalCostLimit: 4 MB` blinda contra dashboards muy grandes
    private let dashboardCache: NSCache<NSString, AnyObject> = {
        let cache = NSCache<NSString, AnyObject>()
        cache.countLimit = 4
        cache.totalCostLimit = 4 * 1024 * 1024
        cache.name = "inventoryInsights.dashboards"
        return cache
    }()

    // FIX: Caching — wrappers de referencia para guardar structs (Sendable
    // pero value-type) en NSCache, que requiere `AnyObject`.
    private final class CachedRestock: AnyObject {
        let value: RestockCyclesDashboard
        let cachedAt: Date
        init(_ v: RestockCyclesDashboard) { self.value = v; self.cachedAt = Date() }
    }
    private final class CachedExpiration: AnyObject {
        let value: ExpirationInsightsDashboard
        let cachedAt: Date
        init(_ v: ExpirationInsightsDashboard) { self.value = v; self.cachedAt = Date() }
    }
    private static let restockKey: NSString = "restockDashboard"
    private static let expirationKey: NSString = "expirationDashboard"
    private let ttl: TimeInterval = 5 * 60

    private var cancellables: Set<AnyCancellable> = []
    private var cycleStreamTask: Task<Void, Never>?

    init() {
        NotificationCenter.default.publisher(for: .inventoryDidChange)
            .sink { [weak self] _ in self?.invalidateCache() }
            .store(in: &cancellables)

        // FIX: Multithreading (AsyncSequence) — observamos el stream del
        // `RestockCycleStore`. Cada vez que se registra un ciclo nuevo (por
        // ejemplo, cuando `InventoryViewModel.logRestockIfNeeded` graba uno),
        // invalidamos el caché de BQ3 para que la próxima lectura sea fresh.
        // Esto reemplaza el patrón "poll cada N segundos" por reactividad
        // real basada en eventos.
        cycleStreamTask = Task { [weak self] in
            guard let stream = await Self.cycleStreamHandle() else { return }
            for await _ in stream {
                await MainActor.run {
                    self?.dashboardCache.removeObject(forKey: Self.restockKey)
                }
            }
        }
    }

    deinit {
        cycleStreamTask?.cancel()
    }

    // FIX: AsyncSequence — helper para acceder al stream nonisolated del actor.
    private static func cycleStreamHandle() async -> AsyncStream<RestockCycle>? {
        RestockCycleStore.shared.cycleEvents
    }

    /// Re-computes BQ3 and BQ4 in parallel.
    /// `forceFresh = true` bypasses the in-memory TTL cache.
    func refresh(products: [Product], forceFresh: Bool = false) async {
        // Seed BQ3 inputs if the on-disk log is empty (first-run demo data).
        await cycleStore.backfillIfEmpty(from: products)

        async let bq3: () = refreshRestock(products: products, forceFresh: forceFresh)
        async let bq4: () = refreshExpiration(products: products, forceFresh: forceFresh)
        _ = await (bq3, bq4)
    }

    func refreshRestock(products: [Product], forceFresh: Bool) async {
        // FIX: Caching — lookup en NSCache con check de TTL. NSCache
        // descarta entradas bajo presión de memoria, no necesitamos
        // limpiar manualmente.
        if !forceFresh,
           let cached = dashboardCache.object(forKey: Self.restockKey) as? CachedRestock,
           Date().timeIntervalSince(cached.cachedAt) < ttl {
            restockDashboard = cached.value
            return
        }
        isLoadingRestock = true
        defer { isLoadingRestock = false }
        let cycles = await cycleStore.cycles(within: 90)
        let result = await cycleAnalyzer.compute(products: products, cycles: cycles)
        restockDashboard = result
        // FIX: Caching — guardamos con cost aproximado (32B por ProductRestockStats).
        dashboardCache.setObject(CachedRestock(result),
                                 forKey: Self.restockKey,
                                 cost: max(1024, result.products.count * 32))
    }

    func refreshExpiration(products: [Product], forceFresh: Bool) async {
        if !forceFresh,
           let cached = dashboardCache.object(forKey: Self.expirationKey) as? CachedExpiration,
           Date().timeIntervalSince(cached.cachedAt) < ttl {
            expirationDashboard = cached.value
            return
        }
        isLoadingExpiration = true
        defer { isLoadingExpiration = false }
        let result = await expirationAnalyzer.compute(products: products)
        expirationDashboard = result
        dashboardCache.setObject(CachedExpiration(result),
                                 forKey: Self.expirationKey,
                                 cost: max(1024, result.totalAtRisk * 32))
    }

    func logRestockIfNeeded(previous: Product?, current: Product) async {
        guard let previous else { return }
        guard previous.quantity == 0, current.quantity > 0 else { return }

        // Heuristic: if we can't tell when it went out of stock, use the
        // product's lastUpdated before the restock happened.
        let outAt = previous.lastUpdated
        let inAt  = current.lastUpdated
        let cycle = RestockCycle(
            productId: current.id,
            productName: current.name,
            outOfStockAt: outAt,
            restockedAt: inAt
        )
        await cycleStore.record(cycle)
        invalidateCache()
    }

    private func invalidateCache() {
        dashboardCache.removeAllObjects()
    }
}
