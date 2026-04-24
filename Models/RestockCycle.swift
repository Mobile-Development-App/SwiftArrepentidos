import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// RestockCycle — one completed out-of-stock → restocked cycle for a product.
// Feeds BQ3 ("average time a product takes to be restocked after running out").
// ─────────────────────────────────────────────────────────────────────────────

struct RestockCycle: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let productId: UUID
    let productName: String
    let outOfStockAt: Date
    let restockedAt: Date

    init(id: UUID = UUID(),
         productId: UUID,
         productName: String,
         outOfStockAt: Date,
         restockedAt: Date) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.outOfStockAt = outOfStockAt
        self.restockedAt = restockedAt
    }

    /// Duration of the cycle in days. Clamped to 0 if the dates are inverted.
    var durationDays: Double {
        let seconds = restockedAt.timeIntervalSince(outOfStockAt)
        return max(0, seconds / 86_400)
    }
}

/// Aggregated BQ3 result for a single product.
struct ProductRestockStats: Identifiable, Hashable, Sendable {
    let productId: UUID
    let productName: String
    let cycles: Int
    let averageDays: Double
    let minDays: Double
    let maxDays: Double
    let lastRestockAt: Date?

    var id: UUID { productId }
}

/// Top-level BQ3 dashboard payload.
struct RestockCyclesDashboard: Sendable {
    let overallAverageDays: Double
    let totalCycles: Int
    let longestCycleDays: Double
    let shortestCycleDays: Double
    let products: [ProductRestockStats]
    let computedAt: Date
    let durationMs: Double
}
