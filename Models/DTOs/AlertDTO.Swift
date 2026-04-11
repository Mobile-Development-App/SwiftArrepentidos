import Foundation

/// DTO matching the backend's alert JSON structure
struct AlertDTO: Decodable {
    let id: String
    let storeId: String?
    let productId: String?
    let type: String
    let priority: String
    let title: String?
    let message: String
    let productName: String?
    let isRead: Bool
    let createdAt: FirestoreTimestamp?
    let readAt: FirestoreTimestamp?

    func toDomain() -> InventoryAlert {
        InventoryAlert(
            id: UUID(deterministicFrom: id),
            title: title ?? AlertDTO.defaultTitle(for: type),
            message: message,
            type: AlertType.fromBackend(type),
            priority: AlertPriority.fromBackend(priority),
            productId: productId != nil ? UUID(deterministicFrom: productId!) : nil,
            productName: productName,
            isRead: isRead,
            createdAt: createdAt?.date ?? Date()
        )
    }

    static func defaultTitle(for type: String) -> String {
        switch type.uppercased() {
        case "LOW_STOCK": return "Stock Bajo"
        case "OUT_OF_STOCK": return "Producto Agotado"
        case "EXPIRING_SOON": return "Proximo a Expirar"
        case "EXPIRED": return "Lote Expirado"
        case "MARGIN_WARNING": return "Margen Bajo"
        case "DEAD_STOCK": return "Stock Muerto"
        case "PRICE_CHANGE": return "Cambio de Precio"
        default: return "Alerta"
        }
    }
}

/// Alert summary from /alerts/summary
struct AlertSummaryDTO: Decodable {
    let total: Int?
    let unread: Int?
    let byCritical: Int?
    let byWarning: Int?
    let byInfo: Int?
}


extension AlertType {
    static func fromBackend(_ type: String) -> AlertType {
        switch type.uppercased() {
        case "LOW_STOCK": return .lowStock
        case "OUT_OF_STOCK": return .outOfStock
        case "EXPIRING_SOON": return .expiringSoon
        case "EXPIRED": return .expired
        case "MARGIN_WARNING": return .priceChange
        case "DEAD_STOCK": return .lowStock // Closest match
        case "PRICE_CHANGE": return .priceChange
        default: return .lowStock
        }
    }

    var backendValue: String {
        switch self {
        case .lowStock: return "LOW_STOCK"
        case .outOfStock: return "OUT_OF_STOCK"
        case .expiringSoon: return "EXPIRING_SOON"
        case .expired: return "EXPIRED"
        case .priceChange: return "PRICE_CHANGE"
        case .newProduct: return "PRICE_CHANGE"
        case .restock: return "LOW_STOCK"
        }
    }
}


extension AlertPriority {
    static func fromBackend(_ priority: String) -> AlertPriority {
        switch priority.uppercased() {
        case "CRITICAL": return .high
        case "WARNING": return .medium
        case "INFO": return .low
        default: return .medium
        }
    }

    var backendValue: String {
        switch self {
        case .high: return "CRITICAL"
        case .medium: return "WARNING"
        case .low: return "INFO"
        }
    }
}
