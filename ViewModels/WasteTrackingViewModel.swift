import SwiftUI
import Combine


@MainActor
final class WasteTrackingViewModel: ObservableObject {

    @Published private(set) var events: [WasteEvent] = []
    @Published private(set) var report: WasteReport?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let store = WasteStore.shared
    private let analytics = WasteAnalyticsService.shared
    private let windowDays = 30

    /// Carga los eventos y computa el reporte. El reporte sale de caché si
    /// el contenido no cambió desde la última vez.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        events = await store.allEvents()
        report = await analytics.report(events: events, windowDays: windowDays)
    }

    /// Registra una merma. Persiste en `WasteStore`, **invalida la caché**
    /// del reporte y recarga.
    func recordWaste(product: Product, quantity: Int, reason: WasteReason) async {
        guard quantity > 0, quantity <= 1_000_000 else {
            errorMessage = "Cantidad inválida."
            return
        }
        let event = WasteEvent(
            productId: product.id,
            productName: product.name,
            category: product.category,
            quantity: quantity,
            unitCost: product.costPrice,
            reason: reason
        )
        await store.record(event)

        // Invalidación explícita: el reporte cacheado quedó obsoleto.
        analytics.invalidate()

        // Audit del registro (dual-write a SwiftData vía PersistenceService).
        PersistenceService.shared.logAuditEvent(
            AuditEvent(
                userId: UUID(),
                userName: "Usuario",
                action: "Merma Registrada",
                entityType: "Waste",
                entityId: product.id,
                entityName: product.name,
                details: "\(quantity) uds · \(reason.rawValue) · " +
                         "\(event.valueLost.compactCurrency)"
            )
        )

        await load()
        HapticManager.notification(.success)
    }

    var recentEvents: [WasteEvent] { Array(events.prefix(20)) }
}
