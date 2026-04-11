import Foundation

/// DTO matching the backend's product JSON structure
struct ProductDTO: Decodable {
    let id: String
    let storeId: String?
    let categoryId: String?
    let supplierId: String?
    let name: String
    let sku: String
    let barcode: String?
    let costPrice: Double
    let sellingPrice: Double
    let margin: Double?
    let currentStock: Int
    let minStock: Int
    let location: String?
    let imageUrl: String?
    let unit: String?
    let registrationMethod: String?
    let isDeleted: Bool?
    let createdAt: FirestoreTimestamp?
    let updatedAt: FirestoreTimestamp?

    /// Convert backend DTO to frontend Product model
    func toDomain() -> Product {
        Product(
            id: UUID(uuidString: id) ?? UUID(deterministicFrom: id),
            name: name,
            sku: sku,
            barcode: barcode ?? "",
            category: ProductCategory.fromBackendId(categoryId ?? "other"),
            supplier: supplierId ?? "",
            costPrice: costPrice,
            salePrice: sellingPrice,
            quantity: currentStock,
            minStock: minStock,
            location: location ?? "",
            expirationDate: nil, // Comes from batches
            imageURL: imageUrl,
            description: "",
            lastUpdated: updatedAt?.date ?? Date(),
            isActive: !(isDeleted ?? false)
        )
    }
}

/// Request body for creating a product
struct CreateProductRequest: Encodable {
    let name: String
    let sku: String
    let barcode: String?
    let categoryId: String
    let costPrice: Double
    let sellingPrice: Double
    let minStock: Int
    let location: String?
    let unit: String?
    let imageUrl: String?
    let registrationMethod: String?
}

/// Request body for updating a product (partial)
struct UpdateProductRequest: Encodable {
    let name: String?
    let sku: String?
    let barcode: String?
    let categoryId: String?
    let costPrice: Double?
    let sellingPrice: Double?
    let minStock: Int?
    let location: String?
    let imageUrl: String?

    init(from product: Product) {
        self.name = product.name
        self.sku = product.sku
        self.barcode = product.barcode.isEmpty ? nil : product.barcode
        self.categoryId = product.category.backendId
        self.costPrice = product.costPrice
        self.sellingPrice = product.salePrice
        self.minStock = product.minStock
        self.location = product.location.isEmpty ? nil : product.location
        self.imageUrl = product.imageURL
    }
}


extension Product {
    func toCreateRequest() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "sku": sku,
            "categoryId": category.backendId,
            "costPrice": costPrice,
            "sellingPrice": salePrice,
            "currentStock": quantity,
            "minStock": minStock
        ]
        if !barcode.isEmpty { dict["barcode"] = barcode }
        if !location.isEmpty { dict["location"] = location }
        if !supplier.isEmpty { dict["supplierId"] = supplier }
        if let imageURL { dict["imageUrl"] = imageURL }
        if !description.isEmpty { dict["description"] = description }
        return dict
    }

    func toUpdateRequest() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "sku": sku,
            "categoryId": category.backendId,
            "costPrice": costPrice,
            "sellingPrice": salePrice,
            "currentStock": quantity,
            "minStock": minStock,
            "location": location
        ]
        if !barcode.isEmpty { dict["barcode"] = barcode }
        if !supplier.isEmpty { dict["supplierId"] = supplier }
        if let imageURL { dict["imageUrl"] = imageURL }
        return dict
    }
}

extension ProductCategory {
    static func fromBackendId(_ id: String) -> ProductCategory {
        switch id.lowercased() {
        case "beverages", "bebidas": return .beverages
        case "dairy", "lacteos", "lácteos": return .dairy
        case "snacks": return .snacks
        case "cleaning", "limpieza": return .cleaning
        case "personal_care", "cuidado_personal", "personalcare", "higiene": return .personalCare
        case "grains", "granos": return .grains
        case "fruits", "frutas", "fruits_vegetables": return .fruits
        case "meat", "carnes": return .meat
        case "bakery", "panaderia", "panadería": return .bakery
        case "frozen", "congelados": return .frozen
        case "condiments", "condimentos": return .condiments
        case "otros", "other": return .other
        default: return .other
        }
    }

    var backendId: String {
        switch self {
        case .beverages: return "bebidas"
        case .dairy: return "lacteos"
        case .snacks: return "snacks"
        case .cleaning: return "limpieza"
        case .personalCare: return "higiene"
        case .grains: return "granos"
        case .fruits: return "frutas"
        case .meat: return "carnes"
        case .bakery: return "panaderia"
        case .frozen: return "congelados"
        case .condiments: return "condimentos"
        case .other: return "otros"
        }
    }
}


extension UUID {
    /// Creates a deterministic UUID from a string (for mapping backend String IDs to UUIDs)
    init(deterministicFrom string: String) {
        let hash = string.utf8.reduce(into: [UInt8](repeating: 0, count: 16)) { result, byte in
            for i in 0..<16 {
                result[i] = result[i] &+ byte &+ UInt8(i)
            }
        }
        self = UUID(uuid: (
            hash[0], hash[1], hash[2], hash[3],
            hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11],
            hash[12], hash[13], hash[14], hash[15]
        ))
    }
}
