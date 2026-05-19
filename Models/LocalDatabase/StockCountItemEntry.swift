import Foundation
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// StockCountItemEntry — Sprint 4. Renglón de un conteo físico, persistido en
// SwiftData. Llave foránea (`session`) a `StockCountSessionEntry`.
//
// `countedQuantity` es opcional: `nil` mientras el usuario no haya contado
// ese producto. `category` se guarda como `String` (raw value de
// `ProductCategory`) para que SwiftData lo pueda indexar y consultar con
// `#Predicate`.
// ─────────────────────────────────────────────────────────────────────────────

@Model
final class StockCountItemEntry {
    @Attribute(.unique) var id: UUID
    var productId: UUID
    var productName: String
    var categoryRaw: String
    var systemQuantity: Int
    /// `nil` hasta que el usuario registra la cantidad física.
    var countedQuantity: Int?
    var costPrice: Double

    var session: StockCountSessionEntry?

    init(id: UUID = UUID(),
         productId: UUID,
         productName: String,
         categoryRaw: String,
         systemQuantity: Int,
         countedQuantity: Int? = nil,
         costPrice: Double,
         session: StockCountSessionEntry? = nil) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.categoryRaw = categoryRaw
        self.systemQuantity = systemQuantity
        self.countedQuantity = countedQuantity
        self.costPrice = costPrice
        self.session = session
    }

    var category: ProductCategory {
        ProductCategory(rawValue: categoryRaw) ?? .other
    }

    var isCounted: Bool { countedQuantity != nil }

    /// Convierte la fila persistida al tipo de dominio `StockCountItem`.
    func toDomain() -> StockCountItem {
        StockCountItem(
            id: id,
            productId: productId,
            productName: productName,
            category: category,
            systemQuantity: systemQuantity,
            countedQuantity: countedQuantity,
            costPrice: costPrice
        )
    }
}
