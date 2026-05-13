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

        let pid = cycle.productId
        let pname = cycle.productName
        let outAt = cycle.outOfStockAt
        let inAt = cycle.restockedAt
        Task { @MainActor in
            LocalDatabaseService.shared.insertRestockCycle(
                productId: pid,
                productName: pname,
                outOfStockAt: outAt,
                restockedAt: inAt
            )
        }
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
