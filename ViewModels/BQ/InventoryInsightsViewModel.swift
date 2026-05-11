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

    // Tiny TTL cache to avoid recomputing while the user toggles around.
    private struct CacheEntry<T> {
        let value: T
        let at: Date
    }
    private var restockCache: CacheEntry<RestockCyclesDashboard>?
    private var expirationCache: CacheEntry<ExpirationInsightsDashboard>?
    private let ttl: TimeInterval = 5 * 60

    private var cancellables: Set<AnyCancellable> = []

    init() {
        NotificationCenter.default.publisher(for: .inventoryDidChange)
            .sink { [weak self] _ in self?.invalidateCache() }
            .store(in: &cancellables)
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
        if !forceFresh,
           let hit = restockCache,
           Date().timeIntervalSince(hit.at) < ttl {
            restockDashboard = hit.value
            return
        }
        isLoadingRestock = true
        defer { isLoadingRestock = false }
        let cycles = await cycleStore.cycles(within: 90)
        let result = await cycleAnalyzer.compute(products: products, cycles: cycles)
        restockDashboard = result
        restockCache = CacheEntry(value: result, at: Date())
    }

    func refreshExpiration(products: [Product], forceFresh: Bool) async {
        if !forceFresh,
           let hit = expirationCache,
           Date().timeIntervalSince(hit.at) < ttl {
            expirationDashboard = hit.value
            return
        }
        isLoadingExpiration = true
        defer { isLoadingExpiration = false }
        let result = await expirationAnalyzer.compute(products: products)
        expirationDashboard = result
        expirationCache = CacheEntry(value: result, at: Date())
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
        restockCache = nil
        expirationCache = nil
    }
}
