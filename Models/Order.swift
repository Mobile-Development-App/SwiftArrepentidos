import Foundation

struct Order: Identifiable, Codable {
    let id: UUID
    var orderNumber: String
    var supplier: String
    var status: OrderStatus
    var totalAmount: Double
    var itemCount: Int
    var createdAt: Date
    var expectedDelivery: Date?

    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "$0"
    }
}

enum OrderStatus: String, CaseIterable, Codable {
    case pending = "Pendiente"
    case confirmed = "Confirmado"
    case shipped = "Enviado"
    case delivered = "Entregado"
    case cancelled = "Cancelado"

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .confirmed: return "checkmark.circle.fill"
        case .shipped: return "shippingbox.fill"
        case .delivered: return "checkmark.seal.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .confirmed: return "blue"
        case .shipped: return "purple"
        case .delivered: return "green"
        case .cancelled: return "red"
        }
    }
}
