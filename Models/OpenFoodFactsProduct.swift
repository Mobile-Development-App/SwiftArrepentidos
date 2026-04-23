import Foundation

/// Response wrapper from Open Food Facts API
/// https://world.openfoodfacts.org/api/v0/product/<barcode>.json
struct OpenFoodFactsResponse: Decodable {
    let code: String?
    let status: Int          // 0 = not found, 1 = found
    let statusVerbose: String?
    let product: OpenFoodFactsProductDTO?

    enum CodingKeys: String, CodingKey {
        case code, status, product
        case statusVerbose = "status_verbose"
    }
}

/// DTO matching the Open Food Facts product payload
struct OpenFoodFactsProductDTO: Decodable {
    let productName: String?
    let brands: String?
    let imageUrl: String?
    let imageFrontUrl: String?
    let categories: String?
    let quantity: String?

    enum CodingKeys: String, CodingKey {
        case brands, categories, quantity
        case productName = "product_name"
        case imageUrl = "image_url"
        case imageFrontUrl = "image_front_url"
    }

    /// Convert external API DTO to a lightweight domain model
    func toDomain(barcode: String) -> OpenFoodFactsProduct {
        OpenFoodFactsProduct(
            barcode: barcode,
            name: productName ?? "",
            brand: brands ?? "",
            imageURL: imageFrontUrl ?? imageUrl,
            category: categories?
                .components(separatedBy: ",")
                .first?
                .trimmingCharacters(in: .whitespaces) ?? "",
            quantity: quantity ?? ""
        )
    }
}



/// Domain model for a product looked up via Open Food Facts.
/// Used to pre-fill the Add Product form when a scanned barcode
/// doesn't exist in our own backend.
struct OpenFoodFactsProduct {
    let barcode: String
    let name: String
    let brand: String
    let imageURL: String?
    let category: String
    let quantity: String
}
