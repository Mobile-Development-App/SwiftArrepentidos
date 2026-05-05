import Foundation
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// UserSession — tabla raíz del esquema relacional local (SwiftData / SQLite).
//
// Cada inicio de sesión crea (o recupera) una fila en `UserSession`. Las
// dos tablas hijas (`AuditLogEntry` y `UsageEventRecord`) cuelgan de aquí
// vía `@Relationship`, dándonos un esquema 1-N real:
//
//   UserSession ──┬── AuditLogEntry      (deleteRule: .cascade)
//                 └── UsageEventRecord    (deleteRule: .cascade)
//
// SwiftData persiste por debajo en un store SQLite gestionado por el
// `ModelContainer`, cumpliendo la categoría "BD Local Relacional" de la
// rúbrica de Sprint 3.
// ─────────────────────────────────────────────────────────────────────────────

@Model
final class UserSession {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var userName: String
    var startedAt: Date
    var endedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \AuditLogEntry.session)
    var auditEntries: [AuditLogEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \UsageEventRecord.session)
    var usageEvents: [UsageEventRecord] = []

    init(id: UUID = UUID(),
         userId: UUID,
         userName: String,
         startedAt: Date = Date(),
         endedAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var isActive: Bool { endedAt == nil }
}
