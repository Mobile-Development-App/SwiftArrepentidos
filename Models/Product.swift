import Foundation

/// Estado de sincronización del producto contra el backend. Vive en el modelo
/// porque la UI lo usa para mostrar badges ("⏳ Pendiente") y porque la
/// `OfflineQueueService` lo lee para decidir si coalescer ops o enviar al
/// backend tal cual.
enum SyncStatus: String, Codable {
    /// El producto fue creado offline y el backend aún no lo conoce. Cualquier
    /// edición sobre él debe MERGEARSE con la operación `createProduct` ya
    /// encolada — NO debe generar una `updateProduct` (el backend daría 404).
    case pendingCreate
    /// El producto ya existe en el backend pero hay una `updateProduct`
    /// encolada con cambios locales aún no sincronizados.
    case pendingUpdate
    /// El producto ya viene del backend o fue creado offline y luego
    /// sincronizado. Es el estado por defecto.
    case synced
}

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

    /// Estado de sincronización offline. Default `.synced` para no romper
    /// la decodificación de JSONs viejos (omitting key in decode → uses default).
    var syncStatus: SyncStatus = .synced

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

    /// Init estándar usado en todo el código. Default `.synced` para callers
    /// que no se enteran del estado de sincronización (la mayoría).
    init(id: UUID = UUID(),
         name: String,
         sku: String,
         barcode: String,
         category: ProductCategory,
         supplier: String,
         costPrice: Double,
         salePrice: Double,
         quantity: Int,
         minStock: Int,
         location: String,
         expirationDate: Date? = nil,
         imageURL: String? = nil,
         description: String,
         lastUpdated: Date,
         isActive: Bool,
         syncStatus: SyncStatus = .synced) {
        self.id = id
        self.name = name
        self.sku = sku
        self.barcode = barcode
        self.category = category
        self.supplier = supplier
        self.costPrice = costPrice
        self.salePrice = salePrice
        self.quantity = quantity
        self.minStock = minStock
        self.location = location
        self.expirationDate = expirationDate
        self.imageURL = imageURL
        self.description = description
        self.lastUpdated = lastUpdated
        self.isActive = isActive
        self.syncStatus = syncStatus
    }

    // Codable manual: JSONs viejos (Sprint 3 y antes) no tienen `syncStatus`,
    // y la síntesis automática de Codable fallaría con keyNotFound. Decodificamos
    // con `decodeIfPresent` para que la migración sea transparente.
    private enum CodingKeys: String, CodingKey {
        case id, name, sku, barcode, category, supplier
        case costPrice, salePrice, quantity, minStock
        case location, expirationDate, imageURL, description
        case lastUpdated, isActive, syncStatus
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.sku = try c.decode(String.self, forKey: .sku)
        self.barcode = try c.decode(String.self, forKey: .barcode)
        self.category = try c.decode(ProductCategory.self, forKey: .category)
        self.supplier = try c.decode(String.self, forKey: .supplier)
        self.costPrice = try c.decode(Double.self, forKey: .costPrice)
        self.salePrice = try c.decode(Double.self, forKey: .salePrice)
        self.quantity = try c.decode(Int.self, forKey: .quantity)
        self.minStock = try c.decode(Int.self, forKey: .minStock)
        self.location = try c.decode(String.self, forKey: .location)
        self.expirationDate = try c.decodeIfPresent(Date.self, forKey: .expirationDate)
        self.imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        self.description = try c.decode(String.self, forKey: .description)
        self.lastUpdated = try c.decode(Date.self, forKey: .lastUpdated)
        self.isActive = try c.decode(Bool.self, forKey: .isActive)
        self.syncStatus = try c.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .synced
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
