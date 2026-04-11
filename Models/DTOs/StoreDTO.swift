import Foundation

struct StoreDTO: Decodable {
    let id: String
    let name: String
    let address: String?
    let phone: String?
    let currency: String?
    let language: String?
    let timezone: String?
    let darkMode: Bool?
    let predictiveRestockEnabled: Bool?
    let alertConfig: AlertConfigDTO?
    let createdAt: FirestoreTimestamp?
    let updatedAt: FirestoreTimestamp?

    func toDomain() -> Store {
        Store(
            id: UUID(deterministicFrom: id),
            name: name,
            address: address ?? "",
            phone: phone ?? "",
            email: "",
            manager: "",
            employeeCount: 0,
            productCount: 0,
            monthlySales: 0,
            isActive: true,
            createdAt: createdAt?.date ?? Date()
        )
    }
}

struct AlertConfigDTO: Decodable {
    let lowStockEnabled: Bool?
    let expirationEnabled: Bool?
    let expirationDays: Int?
}
