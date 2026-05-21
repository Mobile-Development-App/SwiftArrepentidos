import Foundation



/// Causa de la merma
enum WasteReason: String, Codable, CaseIterable, Hashable, Sendable {
    case expired  = "Vencido"
    case damaged  = "Dañado"
    case lost     = "Robo/Pérdida"
    case other    = "Otro"

    var icon: String {
        switch self {
        case .expired: return "calendar.badge.exclamationmark"
        case .damaged: return "hammer.fill"
        case .lost:    return "questionmark.circle.fill"
        case .other:   return "ellipsis.circle.fill"
        }
    }
}

struct WasteEvent: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let productId: UUID
    let productName: String
    let category: ProductCategory
    let quantity: Int
    /// Costo unitario del producto al momento de la merma.
    let unitCost: Double
    let reason: WasteReason
    let recordedAt: Date

    init(id: UUID = UUID(),
         productId: UUID,
         productName: String,
         category: ProductCategory,
         quantity: Int,
         unitCost: Double,
         reason: WasteReason,
         recordedAt: Date = Date()) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.category = category
        self.quantity = quantity
        self.unitCost = unitCost
        self.reason = reason
        self.recordedAt = recordedAt
    }

    var valueLost: Double { Double(quantity) * unitCost }
}

struct WasteCategoryBreakdown: Identifiable, Hashable, Sendable {
    let category: ProductCategory
    let events: Int
    let unitsLost: Int
    let valueLost: Double
    var id: String { category.rawValue }
}

struct WasteReasonBreakdown: Identifiable, Hashable, Sendable {
    let reason: WasteReason
    let events: Int
    let unitsLost: Int
    let valueLost: Double
    var id: String { reason.rawValue }
}

/// Reporte de mermas completo 
struct WasteReport: Sendable {
    let totalEvents: Int
    let totalUnitsLost: Int
    let totalValueLost: Double
    let byCategory: [WasteCategoryBreakdown]
    let byReason: [WasteReasonBreakdown]
    let windowDays: Int
    let computedAt: Date
    /// Tiempo de cómputo en ms. Si vino de caché será ~0.
    let durationMs: Double
    /// `true` si el resultado se sirvió desde la caché.
    let fromCache: Bool

    static let empty = WasteReport(
        totalEvents: 0, totalUnitsLost: 0, totalValueLost: 0,
        byCategory: [], byReason: [], windowDays: 30,
        computedAt: Date(), durationMs: 0, fromCache: false
    )
}
