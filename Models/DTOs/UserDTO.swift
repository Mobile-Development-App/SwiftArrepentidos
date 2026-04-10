import Foundation

/// DTO matching the backend's user/auth JSON responses
struct AuthLoginRequest {
    let uid: String
    let storeId: String

    var toDict: [String: Any] {
        ["uid": uid, "storeId": storeId]
    }
}

struct AuthRegisterRequest {
    let email: String
    let password: String
    let name: String
    let storeName: String
    let storeAddress: String?
    let storePhone: String?

    var toDict: [String: Any] {
        [
            "email": email,
            "password": password,
            "name": name,
            "storeName": storeName,
            "storeAddress": storeAddress ?? "Sin direccion",
            "storePhone": storePhone ?? "+0000000"
        ]
    }
}

struct AuthResponseDTO: Decodable {
    let uid: String
    let storeId: String
    let email: String
    let name: String
    let role: String

    func toDomain() -> User {
        User(
            id: UUID(deterministicFrom: uid),
            fullName: name,
            email: email,
            phone: "",
            role: UserRole.fromBackend(role),
            storeName: "",
            storeId: UUID(deterministicFrom: storeId),
            avatarURL: nil,
            joinDate: Date(),
            isActive: true
        )
    }
}

/// Full user DTO from backend
struct UserDTO: Decodable {
    let id: String
    let storeId: String?
    let email: String
    let name: String
    let role: String
    let isActive: Bool?
    let createdAt: FirestoreTimestamp?
    let lastLogin: FirestoreTimestamp?

    func toDomain() -> User {
        User(
            id: UUID(deterministicFrom: id),
            fullName: name,
            email: email,
            phone: "",
            role: UserRole.fromBackend(role),
            storeName: "",
            storeId: storeId != nil ? UUID(deterministicFrom: storeId!) : nil,
            avatarURL: nil,
            joinDate: createdAt?.date ?? Date(),
            isActive: isActive ?? true
        )
    }
}

// MARK: - UserRole Backend Mapping

extension UserRole {
    static func fromBackend(_ role: String) -> UserRole {
        switch role.uppercased() {
        case "OWNER": return .owner
        case "MANAGER": return .manager
        case "EMPLOYEE": return .employee
        default: return .employee
        }
    }

    var backendValue: String {
        switch self {
        case .owner: return "OWNER"
        case .manager: return "MANAGER"
        case .employee: return "EMPLOYEE"
        }
    }
}
