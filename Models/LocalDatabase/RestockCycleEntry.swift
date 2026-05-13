import Foundation
import SwiftData

@Model
final class RestockCycleEntry {
    @Attribute(.unique) var id: UUID
    var productId: UUID
    var productName: String
    var outOfStockAt: Date
    var restockedAt: Date
    var durationDays: Double

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
        self.durationDays = restockedAt.timeIntervalSince(outOfStockAt) / 86_400
    }
}
