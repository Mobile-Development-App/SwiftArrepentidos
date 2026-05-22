import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// SupplierPerformanceService — Sprint 4. Computa el reporte de BQ11
// (desempeño / volumen de órdenes por proveedor).
//
// El agregado corre en `Task.detached(.userInitiated)` para no bloquear el
// @MainActor mientras se recorren las órdenes. Opera 100% sobre datos
// locales (`PurchaseOrderStore`) — responde aunque no haya conexión.
// ─────────────────────────────────────────────────────────────────────────────

enum SupplierPerformanceService {

    /// Agrega las órdenes por proveedor. `Sendable` in / `Sendable` out, así
    /// que es seguro correrlo en una tarea desprendida del main.
    static func report(orders: [PurchaseOrder]) async -> SupplierPerformanceReport {
        await Task.detached(priority: .userInitiated) {
            let start = Date()

            var bySupplier: [UUID: (name: String, orders: Int, items: Int,
                                    total: Double, pending: Int)] = [:]
            for order in orders {
                var agg = bySupplier[order.supplierId]
                    ?? (order.supplierName, 0, 0, 0, 0)
                agg.name = order.supplierName
                agg.orders += 1
                agg.items += order.itemCount
                agg.total += order.total
                if order.syncState == .pendingSync { agg.pending += 1 }
                bySupplier[order.supplierId] = agg
            }

            let suppliers = bySupplier
                .map { id, agg in
                    SupplierOrderStats(
                        supplierId: id,
                        supplierName: agg.name,
                        orderCount: agg.orders,
                        itemCount: agg.items,
                        totalCommitted: agg.total,
                        pendingSyncCount: agg.pending
                    )
                }
                .sorted { $0.totalCommitted > $1.totalCommitted }

            let totalCommitted = orders.reduce(0.0) { $0 + $1.total }
            let pending = orders.filter { $0.syncState == .pendingSync }.count
            let elapsed = Date().timeIntervalSince(start) * 1000

            return SupplierPerformanceReport(
                suppliers: suppliers,
                totalOrders: orders.count,
                totalCommitted: totalCommitted,
                pendingSyncOrders: pending,
                computedAt: Date(),
                durationMs: elapsed
            )
        }.value
    }
}
