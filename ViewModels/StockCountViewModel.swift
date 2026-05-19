import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// StockCountViewModel — Sprint 4. Orquesta la feature de Conteo Físico.
//
// Responsabilidades
//   • Crear / retomar la sesión de conteo (persistida en SwiftData).
//   • Registrar la cantidad contada de cada producto.
//   • Disparar la reconciliación concurrente (`StockCountService`) al cerrar.
//
// Concurrencia
//   `@MainActor` por convención de SwiftUI. El cómputo pesado lo delega a
//   `StockCountService.reconcile`, que usa `withTaskGroup`. El view-model
//   sólo `await`-ea el resultado — nunca agrega en el hilo principal.
//
// Eventual connectivity
//   Todo el flujo de conteo es local-first: la sesión vive en SwiftData y
//   funciona sin red. `applyAdjustments` empuja las correcciones al
//   inventario vía `InventoryViewModel.updateProduct`, que ya encola en el
//   `OfflineQueueService` si no hay conexión.
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class StockCountViewModel: ObservableObject {

    /// Renglones del conteo en curso.
    @Published private(set) var items: [StockCountItem] = []
    /// Resultado de la reconciliación una vez cerrada la sesión.
    @Published private(set) var summary: StockCountSummary?
    /// `true` mientras `StockCountService.reconcile` corre.
    @Published private(set) var isReconciling = false
    /// `true` si hay una sesión de conteo abierta.
    @Published private(set) var hasActiveSession = false
    @Published var errorMessage: String?

    private let db = LocalDatabaseService.shared
    private var sessionId: UUID?

    // MARK: - Sesión

    /// Llamado al abrir la vista. Si hay un conteo a medias en SwiftData lo
    /// retoma; si no, deja la vista lista para iniciar uno nuevo.
    func restoreActiveSession() {
        guard let session = db.activeStockCountSession() else {
            hasActiveSession = false
            return
        }
        sessionId = session.id
        items = session.items
            .map { $0.toDomain() }
            .sorted { $0.productName < $1.productName }
        hasActiveSession = true
        summary = nil
    }

    /// Crea una sesión de conteo nueva a partir del catálogo de productos
    /// activos. Persiste de inmediato en SwiftData.
    func startNewCount(products: [Product]) {
        let activeProducts = products.filter { $0.isActive }
        guard !activeProducts.isEmpty else {
            errorMessage = "No hay productos activos para contar."
            return
        }
        let newItems: [StockCountItem] = activeProducts.map { product in
            StockCountItem(
                id: UUID(),
                productId: product.id,
                productName: product.name,
                category: product.category,
                systemQuantity: product.quantity,
                countedQuantity: nil,
                costPrice: product.costPrice
            )
        }
        let session = db.createStockCountSession(items: newItems)
        sessionId = session.id
        // Releemos del store para que los `id` de los renglones coincidan
        // con las filas persistidas (los necesitamos para `recordCount`).
        items = session.items
            .map { $0.toDomain() }
            .sorted { $0.productName < $1.productName }
        hasActiveSession = true
        summary = nil
        HapticManager.notification(.success)
    }

    // MARK: - Conteo

    /// Registra la cantidad física contada de un producto. Actualiza la
    /// copia in-memory y persiste el renglón en SwiftData.
    func recordCount(itemId: UUID, quantity: Int) {
        guard quantity >= 0, quantity <= 1_000_000 else {
            errorMessage = "Cantidad inválida."
            return
        }
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index].countedQuantity = quantity
        db.recordCountedQuantity(itemId: itemId, quantity: quantity)
        HapticManager.selection()
    }

    /// Cierra la sesión y reconcilia. El cómputo es concurrente.
    func finishCount() async {
        guard let sessionId else { return }
        isReconciling = true
        defer { isReconciling = false }

        // Cómputo concurrente fuera del main — `withTaskGroup` adentro.
        let result = await StockCountService.reconcile(items: items)

        db.finishStockCountSession(sessionId: sessionId)
        summary = result
        hasActiveSession = false

        // Audit del cierre (dual-write a SwiftData vía PersistenceService).
        PersistenceService.shared.logAuditEvent(
            AuditEvent(
                userId: UUID(),
                userName: "Usuario",
                action: "Conteo Finalizado",
                entityType: "StockCount",
                details: "\(result.countedItems) productos contados · " +
                         "exactitud \(String(format: "%.0f", result.overallAccuracyPct))%"
            )
        )
        HapticManager.notification(.success)
    }

    /// Cancela la sesión activa sin reconciliar.
    func cancelCount() {
        guard let sessionId else { return }
        db.finishStockCountSession(sessionId: sessionId)  // la cierra como completada vacía
        self.sessionId = nil
        items = []
        hasActiveSession = false
        summary = nil
    }

    // MARK: - Derivados para la UI

    var countedCount: Int { items.filter { $0.isCounted }.count }
    var totalCount: Int { items.count }
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(countedCount) / Double(totalCount)
    }
    var allCounted: Bool { totalCount > 0 && countedCount == totalCount }

    /// Productos cuyo conteo no coincide con el sistema — los que ameritan
    /// un ajuste de inventario.
    var discrepantItems: [StockCountItem] {
        items.filter { $0.hasDiscrepancy }
    }
}
