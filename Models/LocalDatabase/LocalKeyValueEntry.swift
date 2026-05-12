import Foundation
import SwiftData


@Model
final class LocalKeyValueEntry {
    @Attribute(.unique) var key: String
    var value: Data
    var expiresAt: Date?
    var updatedAt: Date

    init(key: String,
         value: Data,
         expiresAt: Date? = nil,
         updatedAt: Date = Date()) {
        self.key = key
        self.value = value
        self.expiresAt = expiresAt
        self.updatedAt = updatedAt
    }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }
}
