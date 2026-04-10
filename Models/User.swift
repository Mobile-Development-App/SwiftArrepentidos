import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var fullName: String
    var email: String
    var phone: String
    var role: UserRole
    var storeName: String
    var storeId: UUID?
    var avatarURL: String?
    var joinDate: Date
    var isActive: Bool

    var initials: String {
        let parts = fullName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }
}

enum UserRole: String, CaseIterable, Codable {
    case owner = "Propietario"
    case manager = "Gerente"
    case employee = "Empleado"

    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .manager: return "person.badge.key.fill"
        case .employee: return "person.fill"
        }
    }
}
