import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// PurchaseOrderStore — Sprint 4. Persistencia + sincronización eventual de
// las órdenes de compra (feature de Angel).
//
// `actor` con backing JSON en Application Support (`purchase_orders.json`).
//
// Eventual connectivity strategy
// ──────────────────────────────
// Las órdenes se persisten SIEMPRE en local, haya o no conexión. Cada orden
// lleva un `syncState`:
//   • `.pendingSync` — creada offline, aún sin reconciliar con backend.
//   • `.synced`      — ya reconciliada.
//
// `syncPending()` recorre las órdenes `.pendingSync` y las reconcilia. Lo
// dispara el `PurchaseOrderViewModel` cuando detecta que volvió la conexión
// (vía `ConnectivityService`). El método sólo reconcilia si efectivamente
// hay red — si no, las deja pendientes para el próximo intento.
//
// `// NOTA:` aquí iría el POST real al endpoint `/purchase-orders` del
// backend. Como el backend de Sprint 4 aún no expone ese endpoint, la
// reconciliación marca el estado local — exactamente el mismo patrón que
// `OfflineQueueService` usa para los productos.
// ─────────────────────────────────────────────────────────────────────────────

actor PurchaseOrderStore {
    static let shared = PurchaseOrderStore()

    private let fileName = "purchase_orders.json"
    private var orders: [PurchaseOrder] = []
    private var loaded = false

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager = FileManager.default

    private init() {
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public API

    /// Inserta o actualiza una orden y persiste.
    func save(_ order: PurchaseOrder) {
        loadIfNeeded()
        if let idx = orders.firstIndex(where: { $0.id == order.id }) {
            orders[idx] = order
        } else {
            orders.append(order)
        }
        persist()
        #if DEBUG
        print("[PurchaseOrderStore] saved \(order.orderNumber) · sync=\(order.syncState.rawValue)")
        #endif
    }

    /// Todas las órdenes, más recientes primero.
    func allOrders() -> [PurchaseOrder] {
        loadIfNeeded()
        return orders.sorted { $0.createdAt > $1.createdAt }
    }

    /// Cuántas órdenes están pendientes de sincronizar.
    func pendingSyncCount() -> Int {
        loadIfNeeded()
        return orders.filter { $0.syncState == .pendingSync }.count
    }

    /// Reconcilia las órdenes pendientes. Devuelve los IDs reconciliados.
    /// Sólo actúa si hay conexión — si no, las deja pendientes.
    @discardableResult
    func syncPending(isOnline: Bool) -> [UUID] {
        loadIfNeeded()
        guard isOnline else { return [] }

        var syncedIds: [UUID] = []
        for idx in orders.indices where orders[idx].syncState == .pendingSync {
            // NOTA: aquí iría el POST real a `/purchase-orders`. Sin endpoint
            // de backend, reconciliamos el estado local — mismo patrón que
            // `OfflineQueueService.drain()` para los productos.
            orders[idx].syncState = .synced
            syncedIds.append(orders[idx].id)
        }
        if !syncedIds.isEmpty {
            persist()
            #if DEBUG
            print("[PurchaseOrderStore] synced \(syncedIds.count) pending order(s)")
            #endif
        }
        return syncedIds
    }

    func clear() {
        orders.removeAll()
        try? fileManager.removeItem(at: storageURL())
    }

    // MARK: - Disk I/O

    private func loadIfNeeded() {
        guard !loaded else { return }
        defer { loaded = true }
        let url = storageURL()
        guard fileManager.fileExists(atPath: url.path) else { return }
        if let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode([PurchaseOrder].self, from: data) {
            orders = decoded
        }
    }

    private func persist() {
        let url = storageURL()
        if let data = try? encoder.encode(orders) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func storageURL() -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if !fileManager.fileExists(atPath: base.path) {
            try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base.appendingPathComponent(fileName)
    }
}
