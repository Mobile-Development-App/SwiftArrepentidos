import Foundation

struct Supplier: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var contactName: String
    var email: String
    var phone: String
    var address: String
    var category: String
    var isActive: Bool
}
