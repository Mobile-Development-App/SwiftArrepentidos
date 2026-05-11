import Foundation


actor RestockCycleStore {
    static let shared = RestockCycleStore()

    private let fileName = "restock_cycles.json"
    private var cycles: [RestockCycle] = []
    private var loaded = false
    private let cap = 5_000

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager = FileManager.default

    // FIX: Multithreading (AsyncSequence) — stream de ciclos a medida que
    // se registran. Permite a `InventoryInsightsViewModel` reaccionar con
    // `for await cycle in RestockCycleStore.shared.cycleEvents` y
    // refrescar la BQ3 sin tener que hacer polling.
    //
    // `nonisolated` para que SwiftUI consumers puedan acceder sin hopear
    // dentro del actor — la `Continuation` es thread-safe por sí misma.
    nonisolated let cycleEvents: AsyncStream<RestockCycle>
    private nonisolated let cycleEventsContinuation: AsyncStream<RestockCycle>.Continuation

    private init() {
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601

        // FIX: AsyncStream construction with continuation pattern
        var cont: AsyncStream<RestockCycle>.Continuation!
        self.cycleEvents = AsyncStream { c in cont = c }
        self.cycleEventsContinuation = cont
    }

    // MARK: - Public API

    func record(_ cycle: RestockCycle) {
        loadIfNeeded()
        cycles.append(cycle)
        if cycles.count > cap { cycles.removeFirst(cycles.count - cap / 2) }
        persist()
        // FIX: AsyncSequence — emite el evento al stream para que cualquier
        // observador (BQ3 ViewModel, dashboards) reaccione en tiempo real.
        cycleEventsContinuation.yield(cycle)
    }

    func allCycles() -> [RestockCycle] {
        loadIfNeeded()
        return cycles
    }

    func cycles(within days: Int) -> [RestockCycle] {
        loadIfNeeded()
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        return cycles.filter { $0.restockedAt >= cutoff }
    }

    func clear() {
        cycles.removeAll()
        let url = storageURL()
        try? fileManager.removeItem(at: url)
    }


    func backfillIfEmpty(from products: [Product]) async {
        loadIfNeeded()
        guard cycles.isEmpty, !products.isEmpty else { return }

        // FIX: Multithreading (GCD) — el backfill genera 2-4 ciclos por
        // producto y, con catálogos grandes, fácilmente entra en ~500
        // entradas. Ejecutamos la generación en `DispatchQueue.global(qos: .utility)`
        // para no bloquear el caller (que viene de @MainActor en
        // `InventoryInsightsViewModel.refresh`).
        //
        // Diferencia explícita con Task.detached:
        //   • Task.detached usa el cooperative thread pool de Swift.
        //   • DispatchQueue.global(qos:) es GCD puro, el sistema de
        //     concurrencia clásico de iOS — todavía vigente y necesario
        //     cuando interoperamos con APIs de Foundation que prefieren
        //     callbacks. Aquí lo usamos para demostrar la integración
        //     entre concurrency moderna (await) y GCD legacy.
        let generated: [RestockCycle] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var rng = SystemRandomNumberGenerator()
                let now = Date()
                var result: [RestockCycle] = []
                result.reserveCapacity(products.count * 3)

                for product in products where product.isActive {
                    let cycleCount = Int.random(in: 2...4, using: &rng)
                    var cursor = now.addingTimeInterval(-60 * 86_400)
                    for _ in 0..<cycleCount {
                        let gap = Double.random(in: 2...12, using: &rng) * 86_400
                        let duration = Double.random(in: 1.5...7, using: &rng) * 86_400
                        let outAt = cursor
                        let inAt = outAt.addingTimeInterval(duration)
                        result.append(RestockCycle(
                            productId: product.id,
                            productName: product.name,
                            outOfStockAt: outAt,
                            restockedAt: inAt
                        ))
                        cursor = inAt.addingTimeInterval(gap)
                    }
                }
                continuation.resume(returning: result)
            }
        }

        cycles.append(contentsOf: generated)
        persist()
    }

    // MARK: - Disk I/O

    private func loadIfNeeded() {
        guard !loaded else { return }
        defer { loaded = true }
        let url = storageURL()
        guard fileManager.fileExists(atPath: url.path) else { return }
        if let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode([RestockCycle].self, from: data) {
            cycles = decoded
        }
    }

    private func persist() {
        let url = storageURL()
        if let data = try? encoder.encode(cycles) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func storageURL() -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if !fileManager.fileExists(atPath: base.path) {
            try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base.appendingPathComponent(fileName)
    }
}
