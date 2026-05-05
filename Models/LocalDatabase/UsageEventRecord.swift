import Foundation
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// UsageEventRecord — versión SwiftData del log de uso. La fuente de verdad
// para BQ6 sigue siendo `UsageTrackingService` (actor + JSON), pero cada
// `record` ahora hace **dual-write** a esta tabla relacional para que la
// misma información sea consultable con `@Query` y predicados desde la UI
// (ver `LocalDatabaseDebugView`).
//
// `kind` se guarda como `String` porque SwiftData no soporta enums no-RawRepresentable
// con asociados directamente; el valor crudo viene de `UsageEvent.Kind.rawValue`.
// `attributesJSON` se serializa con `JSONEncoder` para preservar el payload libre.
// ─────────────────────────────────────────────────────────────────────────────

@Model
final class UsageEventRecord {
    @Attribute(.unique) var id: UUID
    var kind: String
    var timestamp: Date
    var attributesJSON: String

    var session: UserSession?

    init(id: UUID = UUID(),
         kind: String,
         timestamp: Date = Date(),
         attributesJSON: String = "{}",
         session: UserSession? = nil) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.attributesJSON = attributesJSON
        self.session = session
    }

    /// Hora del día en la zona horaria local — usada por BQ6 cuando los datos
    /// se reconstruyen desde esta tabla en lugar del JSON.
    var hourOfDay: Int {
        Calendar.current.component(.hour, from: timestamp)
    }

    /// Decodifica `attributesJSON` a `[String: String]`. Devuelve `[:]` si
    /// el blob está corrupto — preferimos perder atributos antes que crashear.
    var attributes: [String: String] {
        guard let data = attributesJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }
}
