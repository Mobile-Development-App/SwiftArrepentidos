import Foundation


/// Estado de negocio de la orden.
enum PurchaseOrderStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case draft     = "Borrador"
    case sent      = "Enviada"
    case received  = "Recibida"
    case cancelled = "Cancelada"

    var icon: String {
        switch self {
        case .draft:     return "doc.text"
        case .sent:      return "paperplane.fill"
        case .received:  return "checkmark.seal.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

/// Estado de sincronización de la orden contra el backend.
enum POSyncState: String, Codable, Hashable, Sendable {
    /// Creada/editada sin confirmar sincronización — vive sólo en local.
    case pendingSync
    /// Reconciliada: el backend la conoce.
    case synced
}

/// Una línea de la orden: un producto con su cantidad y costo unitario.
struct PurchaseOrderLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let productId: UUID
    let productName: String
    let quantity: Int
    let unitCost: Double

    init(id: UUID = UUID(),
         productId: UUID,
         productName: String,
         quantity: Int,
         unitCost: Double) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.quantity = quantity
        self.unitCost = unitCost
    }

    var lineTotal: Double { Double(quantity) * unitCost }
}

/// Una orden de compra completa.
struct PurchaseOrder: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var orderNumber: String
    var supplierId: UUID
    var supplierName: String
    var lines: [PurchaseOrderLine]
    var status: PurchaseOrderStatus
    var syncState: POSyncState
    var createdAt: Date
    /// `true` si la orden se creó sin conexión — usado para evidenciar EvC.
    var createdOffline: Bool

    init(id: UUID = UUID(),
         orderNumber: String,
         supplierId: UUID,
         supplierName: String,
         lines: [PurchaseOrderLine],
         status: PurchaseOrderStatus = .draft,
         syncState: POSyncState = .synced,
         createdAt: Date = Date(),
         createdOffline: Bool = false) {
        self.id = id
        self.orderNumber = orderNumber
        self.supplierId = supplierId
        self.supplierName = supplierName
        self.lines = lines
        self.status = status
        self.syncState = syncState
        self.createdAt = createdAt
        self.createdOffline = createdOffline
    }

    var total: Double { lines.reduce(0) { $0 + $1.lineTotal } }
    var itemCount: Int { lines.reduce(0) { $0 + $1.quantity } }
}

// MARK: - BQ11 (Desempeño por proveedor)

/// Métricas de órdenes agregadas para un proveedor.
struct SupplierOrderStats: Identifiable, Hashable, Sendable {
    let supplierId: UUID
    let supplierName: String
    let orderCount: Int
    let itemCount: Int
    let totalCommitted: Double
    let pendingSyncCount: Int
    var id: UUID { supplierId }
}

/// Reporte de BQ11.
struct SupplierPerformanceReport: Sendable {
    let suppliers: [SupplierOrderStats]
    let totalOrders: Int
    let totalCommitted: Double
    let pendingSyncOrders: Int
    let computedAt: Date
    let durationMs: Double

    static let empty = SupplierPerformanceReport(
        suppliers: [], totalOrders: 0, totalCommitted: 0,
        pendingSyncOrders: 0, computedAt: Date(), durationMs: 0
    )
}
