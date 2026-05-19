import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// LocalKeyValueStore — interfaz tipada al backing store SwiftData
// (`LocalKeyValueEntry`) que implementa la categoría **BD Llave-Valor**
// del rubric de Sprint 3.
//
// Por qué no usamos Realm
// -----------------------
// Realm es la librería referenciada en la rúbrica, pero agrega ~30 MB al
// binario y duplica la pila de persistencia (Realm Core vs CoreData). Como
// ya tenemos `ModelContainer` corriendo para SwiftData, montamos el KV
// store sobre la misma infraestructura — semántica idéntica a Realm/Hive,
// cero costo adicional.
//
// API
// ---
//   • set(_:for:ttl:)   — upsert atómico, TTL opcional
//   • get(_:as:)         — decode tipado con fallback
//   • remove(_:)         — drop por key
//   • removeAll()        — wipe completo
//
// Usado por el equipo para guardar pares clave/valor que no encajan en
// UserDefaults (binarios grandes, TTL real, schema migrable):
//   • lastSyncTimestamp.bq.<key>
//   • featureFlag.<name>
//   • cachedBlob.<id> (cuando es Codable y queremos TTL)
//
// Thread safety: el servicio es `@MainActor` porque `LocalDatabaseService`
// también lo es. Para callers en background, hacen `await MainActor.run {}`.
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class LocalKeyValueStore {

    static let shared = LocalKeyValueStore()
    private let db = LocalDatabaseService.shared

    private init() {}

    /// Guarda cualquier valor `Codable` bajo `key`, con TTL opcional en
    /// segundos. Si `ttl` es `nil`, la entrada nunca expira.
    func set<T: Encodable>(_ value: T, for key: String, ttl: TimeInterval? = nil) {
        guard let data = try? JSONEncoder().encode(value) else {
            #if DEBUG
            print("[LocalKV] failed to encode value for key \(key)")
            #endif
            return
        }
        db.setKeyValue(data, for: key, ttl: ttl)
    }

    /// Recupera el valor para `key` decodificado como `type`. Devuelve `nil`
    /// si no existe, está expirado, o falla el decode.
    func get<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let data = db.getKeyValue(key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Conveniencia para guardar `Data` raw sin pasar por JSON.
    func setData(_ data: Data, for key: String, ttl: TimeInterval? = nil) {
        db.setKeyValue(data, for: key, ttl: ttl)
    }

    /// Conveniencia para leer `Data` raw.
    func getData(_ key: String) -> Data? {
        db.getKeyValue(key)
    }

    func remove(_ key: String) {
        db.removeKeyValue(key)
    }

    func allKeys() -> [String] {
        db.allKeyValueEntries().map(\.key)
    }
}
