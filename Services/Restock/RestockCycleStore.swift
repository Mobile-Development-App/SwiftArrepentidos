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

    private init() {
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public API

    func record(_ cycle: RestockCycle) {
        loadIfNeeded()
        cycles.append(cycle)
        if cycles.count > cap { cycles.removeFirst(cycles.count - cap / 2) }
        persist()
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


    func backfillIfEmpty(from products: [Product]) {
        loadIfNeeded()
        guard cycles.isEmpty, !products.isEmpty else { return }

        var rng = SystemRandomNumberGenerator()
        let now = Date()
        var generated: [RestockCycle] = []

        for product in products where product.isActive {
            let cycleCount = Int.random(in: 2...4, using: &rng)
            var cursor = now.addingTimeInterval(-60 * 86_400) // 60 días atrás
            for _ in 0..<cycleCount {
                let gap = Double.random(in: 2...12, using: &rng) * 86_400
                let duration = Double.random(in: 1.5...7, using: &rng) * 86_400
                let outAt = cursor
                let inAt = outAt.addingTimeInterval(duration)
                generated.append(RestockCycle(
                    productId: product.id,
                    productName: product.name,
                    outOfStockAt: outAt,
                    restockedAt: inAt
                ))
                cursor = inAt.addingTimeInterval(gap)
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
