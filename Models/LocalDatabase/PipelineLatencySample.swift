import Foundation
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// PipelineLatencySample — tabla SwiftData del dominio de Santiago para BQ1.
//
// La fuente histórica (PipelineLogger) sigue persistiendo a JSON para
// compatibilidad. Esta tabla es la versión **relacional** consultable con
// `@Query` y `#Predicate`, demostrando la categoría "BD Local Relacional"
// del rubric en los archivos analíticos de Santiago.
//
// Es independiente de `UserSession` para evitar acoplamiento con auth: los
// samples se graban incluso durante el cold-start antes del login.
// ─────────────────────────────────────────────────────────────────────────────

@Model
final class PipelineLatencySample {
    @Attribute(.unique) var id: UUID
    var stage: String         // raw value of LatencySample.Stage
    var durationMs: Double
    var timestamp: Date

    init(id: UUID = UUID(),
         stage: String,
         durationMs: Double,
         timestamp: Date = Date()) {
        self.id = id
        self.stage = stage
        self.durationMs = durationMs
        self.timestamp = timestamp
    }
}
