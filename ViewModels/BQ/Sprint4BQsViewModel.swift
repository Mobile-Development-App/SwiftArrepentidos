import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// Sprint4BQsViewModel — drives the Sprint 4 Business Questions.
//
//   • BQ9 (Juan Felipe) — Exactitud del inventario por categoría:
//     "¿Qué % de discrepancia hay entre el stock registrado y el conteo
//      físico, desglosado por categoría?"
//
// Fuente de datos: las sesiones de conteo COMPLETADAS persistidas en
// SwiftData (`StockCountSessionEntry`). El view-model lee las filas en el
// `@MainActor`, las convierte a `StockCountItem` (value type `Sendable`) y
// delega la agregación concurrente a `StockCountService.reconcile`, que usa
// `withTaskGroup`. El view-model nunca agrega en el hilo principal.
//
// Eventual connectivity: la BQ se computa 100% sobre datos locales
// (SwiftData) — responde aunque el dispositivo esté sin conexión.
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class Sprint4BQsViewModel: ObservableObject {

    /// Resultado de BQ9 — reconciliación agregada de todos los conteos.
    @Published private(set) var stockAccuracy: StockCountSummary?
    /// Cuántas sesiones de conteo completadas se analizaron.
    @Published private(set) var sessionsAnalyzed = 0
    @Published private(set) var isLoading = false

    private let db = LocalDatabaseService.shared

    /// Recalcula BQ9. Llamado en el `.task` y el pull-to-refresh del
    /// dashboard de Business Questions.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // Lectura relacional: todas las sesiones de conteo completadas.
        let sessions = db.completedStockCountSessions()
        sessionsAnalyzed = sessions.count

        // Aplanamos a renglones de dominio (`Sendable`) para poder cruzarlos
        // al cómputo concurrente sin actor-isolation issues.
        let items: [StockCountItem] = sessions
            .flatMap { $0.items }
            .map { $0.toDomain() }

        guard !items.isEmpty else {
            stockAccuracy = nil
            return
        }

        // Agregación concurrente (TaskGroup) — reutiliza el mismo motor que
        // la feature de conteo físico.
        stockAccuracy = await StockCountService.reconcile(items: items)
    }
}
