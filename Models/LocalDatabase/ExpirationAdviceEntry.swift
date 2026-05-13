import Foundation
import SwiftData

@Model
final class ExpirationAdviceEntry {
    @Attribute(.unique) var id: UUID
    var productId: UUID
    var productName: String
    var category: String
    var quantity: Int
    var daysRemaining: Int
    var urgency: String          
    var action: String          
    var rationale: String
    var computedAt: Date

    init(id: UUID = UUID(),
         productId: UUID,
         productName: String,
         category: String,
         quantity: Int,
         daysRemaining: Int,
         urgency: String,
         action: String,
         rationale: String,
         computedAt: Date = Date()) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.category = category
        self.quantity = quantity
        self.daysRemaining = daysRemaining
        self.urgency = urgency
        self.action = action
        self.rationale = rationale
        self.computedAt = computedAt
    }
}
