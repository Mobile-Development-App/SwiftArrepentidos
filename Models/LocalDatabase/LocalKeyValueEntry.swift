import Foundation
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// LocalKeyValueEntry — backing store SwiftData para `LocalKeyValueStore`.
//
// Implementa la categoría **BD Llave-Valor** del rubric ("Realm o
// equivalente"). No usamos Realm porque agrega 30+ MB al binario; en su
// lugar reutilizamos el `ModelContainer` ya existente con una entidad
// dedicada que sólo guarda pares `key → value` con TTL opcional.
//
// API expuesta por `LocalKeyValueStore`:
//   get(_:as:) / set(_:for:ttl:) / remove(_:) / removeAll()
//
// Igual que Realm/Hive en espíritu: un dict persistente tipado y consultable.
// ─────────────────────────────────────────────────────────────────────────────

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
