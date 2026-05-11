import Foundation
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// AnalyticsEventSample — versión relacional de `AnalyticsEvent` (dominio
// de Santiago), persistida en SwiftData para las BQ5/BQ7/BQ8.
//
// Alimenta el pipeline analítico desde dual-write en `AnalyticsLogService.record`:
// la fuente offline-first sigue siendo el JSON in-memory, y esta tabla
// permite consultas tipadas con `@Query` + `#Predicate` desde la UI.
// ─────────────────────────────────────────────────────────────────────────────

@Model
final class AnalyticsEventSample {
    @Attribute(.unique) var id: UUID
    var kind: String           // raw value of AnalyticsEvent.Kind
    var timestamp: Date
    var attributesJSON: String // [String: String] serialized

    init(id: UUID = UUID(),
         kind: String,
         timestamp: Date = Date(),
         attributesJSON: String = "{}") {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.attributesJSON = attributesJSON
    }

    /// `[String: String]` decodificado lazily desde el JSON crudo.
    var attributes: [String: String] {
        guard let data = attributesJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    var hourOfDay: Int {
        Calendar.current.component(.hour, from: timestamp)
    }
}
