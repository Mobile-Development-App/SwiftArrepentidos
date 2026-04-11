import Foundation

struct Product: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var sku: String
    var barcode: String
    var category: ProductCategory
    var supplier: String
    var costPrice: Double
    var salePrice: Double
    var quantity: Int
    var minStock: Int
    var location: String
    var expirationDate: Date?
    var imageURL: String?
    var description: String
    var lastUpdated: Date
    var isActive: Bool

    var profitMargin: Double {
        guard costPrice > 0 else { return 0 }
        return ((salePrice - costPrice) / costPrice) * 100
    }

    var stockValue: Double {
        return salePrice * Double(quantity)
    }

    var costValue: Double {
        return costPrice * Double(quantity)
    }

    var stockStatus: StockStatus {
        if quantity <= 0 {
            return .outOfStock
        } else if quantity <= minStock {
            return .lowStock
        } else {
            return .inStock
        }
    }

    var isExpiringSoon: Bool {
        guard let expDate = expirationDate else { return false }
        return expDate.timeIntervalSinceNow < 30 * 24 * 3600 && expDate.timeIntervalSinceNow > 0
    }

    var isExpired: Bool {
        guard let expDate = expirationDate else { return false }
        return expDate < Date()
    }
}

enum StockStatus: String, CaseIterable, Codable {
    case inStock = "En Stock"
    case lowStock = "Stock Bajo"
    case outOfStock = "Agotado"

    var color: String {
        switch self {
        case .inStock: return "green"
        case .lowStock: return "orange"
        case .outOfStock: return "red"
        }
    }
}

enum ProductCategory: String, CaseIterable, Hashable, Codable {
    case beverages = "Bebidas"
    case dairy = "Lácteos"
    case snacks = "Snacks"
    case cleaning = "Limpieza"
    case personalCare = "Cuidado Personal"
    case grains = "Granos"
    case fruits = "Frutas y Verduras"
    case meat = "Carnes"
    case bakery = "Panadería"
    case frozen = "Congelados"
    case condiments = "Condimentos"
    case other = "Otros"

    var icon: String {
        switch self {
        case .beverages: return "cup.and.saucer.fill"
        case .dairy: return "drop.fill"
        case .snacks: return "birthday.cake.fill"
        case .cleaning: return "sparkles"
        case .personalCare: return "heart.fill"
        case .grains: return "leaf.fill"
        case .fruits: return "carrot.fill"
        case .meat: return "fork.knife"
        case .bakery: return "basket.fill"
        case .frozen: return "snowflake"
        case .condiments: return "flame.fill"
        case .other: return "shippingbox.fill"
        }
    }
}
