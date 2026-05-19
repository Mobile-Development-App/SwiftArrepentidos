import Foundation
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// StockCountSessionEntry — Sprint 4. Tabla raíz del conteo físico en la BD
// relacional local (SwiftData / SQLite).
//
// Cada sesión de conteo es una fila aquí; sus renglones cuelgan vía
// `@Relationship` 1-N con `StockCountItemEntry` (deleteRule: .cascade).
//
//   StockCountSessionEntry ──< StockCountItemEntry
//
// Local Storage strategy de la feature de Juan Felipe: la sesión completa
// se persiste en SwiftData, así el conteo sobrevive cierres de app y el
// usuario puede retomarlo donde lo dejó — 100% offline.
// ─────────────────────────────────────────────────────────────────────────────

@Model
final class StockCountSessionEntry {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    /// Raw value de `StockCountStatus` (`inProgress` / `completed`).
    var statusRaw: String

    @Relationship(deleteRule: .cascade, inverse: \StockCountItemEntry.session)
    var items: [StockCountItemEntry] = []

    init(id: UUID = UUID(),
         startedAt: Date = Date(),
         finishedAt: Date? = nil,
         statusRaw: String = StockCountStatus.inProgress.rawValue) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.statusRaw = statusRaw
    }

    var status: StockCountStatus {
        StockCountStatus(rawValue: statusRaw) ?? .inProgress
    }

    var isInProgress: Bool { status == .inProgress }
}
