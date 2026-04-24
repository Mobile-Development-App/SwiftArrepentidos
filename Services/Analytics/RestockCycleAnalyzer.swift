import Foundation


final class RestockCycleAnalyzer {
    static let shared = RestockCycleAnalyzer()
    private init() {}


    func compute(products: [Product], cycles: [RestockCycle]) async -> RestockCyclesDashboard {
        let start = Date()

        // Index cycles by productId so each child task walks its own slice —
        // no cross-task contention.
        let grouped: [UUID: [RestockCycle]] = Dictionary(grouping: cycles, by: \.productId)

        // Fan out: one TaskGroup child per product. This is the iOS
        // equivalent of Dart's `Future.wait(productIds.map(...))`.
        let perProduct: [ProductRestockStats] = await withTaskGroup(
            of: ProductRestockStats?.self
        ) { group in
            for product in products where product.isActive {
                let slice = grouped[product.id] ?? []
                group.addTask(priority: .userInitiated) {
                    Self.statsForProduct(product: product, cycles: slice)
                }
            }
            var acc: [ProductRestockStats] = []
            acc.reserveCapacity(products.count)
            for await row in group {
                if let row { acc.append(row) }
            }
            return acc
        }

        let sorted = perProduct.sorted { $0.averageDays > $1.averageDays }
        let allDurations = cycles.map(\.durationDays)
        let overallAvg = allDurations.isEmpty
            ? 0.0
            : allDurations.reduce(0, +) / Double(allDurations.count)
        let longest  = allDurations.max() ?? 0
        let shortest = allDurations.min() ?? 0

        return RestockCyclesDashboard(
            overallAverageDays: overallAvg,
            totalCycles: cycles.count,
            longestCycleDays: longest,
            shortestCycleDays: shortest,
            products: sorted,
            computedAt: Date(),
            durationMs: Date().timeIntervalSince(start) * 1000
        )
    }


    private static func statsForProduct(product: Product,
                                        cycles: [RestockCycle]) -> ProductRestockStats? {
        guard !cycles.isEmpty else {
            return ProductRestockStats(
                productId: product.id,
                productName: product.name,
                cycles: 0,
                averageDays: 0,
                minDays: 0,
                maxDays: 0,
                lastRestockAt: nil
            )
        }
        let durations = cycles.map(\.durationDays)
        let avg = durations.reduce(0, +) / Double(durations.count)
        let last = cycles.map(\.restockedAt).max()
        return ProductRestockStats(
            productId: product.id,
            productName: product.name,
            cycles: cycles.count,
            averageDays: avg,
            minDays: durations.min() ?? 0,
            maxDays: durations.max() ?? 0,
            lastRestockAt: last
        )
    }
}
