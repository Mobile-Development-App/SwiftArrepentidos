import Foundation
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// AuditLogEntry — tabla de auditoría persistida en el store relacional local.
//
// Llave foránea (relacional): `session` apunta a `UserSession`. Si el padre
// se borra, la regla `cascade` declarada en `UserSession.auditEntries` se
// encarga de limpiar también las entradas hijas.
// ─────────────────────────────────────────────────────────────────────────────

@Model
final class AuditLogEntry {
    @Attribute(.unique) var id: UUID
    var action: String
    var entityType: String
    var entityId: UUID?
    var entityName: String?
    var details: String
    var timestamp: Date

    var session: UserSession?

    init(id: UUID = UUID(),
         action: String,
         entityType: String,
         entityId: UUID? = nil,
         entityName: String? = nil,
         details: String,
         timestamp: Date = Date(),
         session: UserSession? = nil) {
        self.id = id
        self.action = action
        self.entityType = entityType
        self.entityId = entityId
        self.entityName = entityName
        self.details = details
        self.timestamp = timestamp
        self.session = session
    }
}
