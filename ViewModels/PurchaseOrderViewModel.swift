import SwiftUI
import Combine

@MainActor
final class PurchaseOrderViewModel: ObservableObject {

    @Published private(set) var orders: [PurchaseOrder] = []
    @Published private(set) var pendingSyncCount = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let store = PurchaseOrderStore.shared
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Eventual connectivity — al volver la red, reconciliar pendientes.
        ConnectivityService.shared.onTransition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] online in
                guard online, let self else { return }
                Task { await self.syncPending() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Carga

    func load() async {
        isLoading = true
        defer { isLoading = false }
        // Si ya hay conexión, reconciliamos lo que haya quedado pendiente.
        if ConnectivityService.shared.isOnline {
            _ = await store.syncPending(isOnline: true)
        }
        orders = await store.allOrders()
        pendingSyncCount = await store.pendingSyncCount()
    }

    // MARK: - Crear orden

    /// Crea una orden de compra. Si no hay conexión nace `.pendingSync` y se
    /// marca `createdOffline` — la UI lo evidencia con un badge.
    func createOrder(supplier: Supplier,
                     lines: [PurchaseOrderLine]) async {
        guard !lines.isEmpty else {
            errorMessage = "Agrega al menos un producto a la orden."
            return
        }
        let online = ConnectivityService.shared.isOnline
        let order = PurchaseOrder(
            orderNumber: "OC-\(Int(Date().timeIntervalSince1970) % 1_000_000)",
            supplierId: supplier.id,
            supplierName: supplier.name,
            lines: lines,
            status: .sent,
            syncState: online ? .synced : .pendingSync,
            createdOffline: !online
        )
        await store.save(order)

        PersistenceService.shared.logAuditEvent(
            AuditEvent(
                userId: UUID(),
                userName: "Usuario",
                action: "Orden de Compra Creada",
                entityType: "PurchaseOrder",
                entityId: order.id,
                entityName: order.orderNumber,
                details: "\(supplier.name) · \(order.itemCount) uds · " +
                         "\(order.total.compactCurrency)" +
                         (online ? "" : " · offline (pendiente de sync)")
            )
        )

        await load()
        HapticManager.notification(.success)
    }

    /// Cambia el estado de negocio de una orden (enviada → recibida, etc.).
    func updateStatus(orderId: UUID, to status: PurchaseOrderStatus) async {
        guard var order = orders.first(where: { $0.id == orderId }) else { return }
        order.status = status
        // Un cambio local que aún no se confirma queda pendiente de sync.
        if ConnectivityService.shared.isOnline {
            order.syncState = .synced
        } else {
            order.syncState = .pendingSync
        }
        await store.save(order)
        await load()
    }

    // MARK: - Sync

    /// Reconcilia las órdenes pendientes y refresca.
    func syncPending() async {
        let online = ConnectivityService.shared.isOnline
        let synced = await store.syncPending(isOnline: online)
        if !synced.isEmpty {
            await load()
        }
    }
}
