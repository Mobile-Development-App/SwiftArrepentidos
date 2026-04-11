import Foundation

struct InventoryAlert: Identifiable, Codable {
    let id: UUID
    var title: String
    var message: String
    var type: AlertType
    var priority: AlertPriority
    var productId: UUID?
    var productName: String?
    var isRead: Bool
    var createdAt: Date

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

enum AlertType: String, CaseIterable, Codable {
    case lowStock = "Stock Bajo"
    case outOfStock = "Agotado"
    case expiringSoon = "Por Vencer"
    case expired = "Vencido"
    case priceChange = "Cambio de Precio"
    case newProduct = "Nuevo Producto"
    case restock = "Reabastecimiento"

    var icon: String {
        switch self {
        case .lowStock: return "exclamationmark.triangle.fill"
        case .outOfStock: return "xmark.circle.fill"
        case .expiringSoon: return "clock.fill"
        case .expired: return "calendar.badge.exclamationmark"
        case .priceChange: return "dollarsign.circle.fill"
        case .newProduct: return "plus.circle.fill"
        case .restock: return "arrow.clockwise.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .lowStock, .expiringSoon: return "warning"
        case .outOfStock, .expired: return "error"
        case .priceChange: return "info"
        case .newProduct, .restock: return "success"
        }
    }
}

enum AlertPriority: String, CaseIterable, Codable {
    case high = "Alta"
    case medium = "Media"
    case low = "Baja"

    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "blue"
        }
    }
}
