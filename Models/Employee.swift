import Foundation

struct Employee: Identifiable, Hashable, Codable {
    let id: UUID
    var fullName: String
    var email: String
    var phone: String
    var role: UserRole
    var storeId: UUID
    var storeName: String
    var joinDate: Date
    var isActive: Bool

    var initials: String {
        let parts = fullName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }
}
