import SwiftUI

struct SupplierPerformanceCard: View {
    let report: SupplierPerformanceReport?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if isLoading && report == nil {
                loadingRow
            } else if let r = report, r.totalOrders > 0 {
                overall(r)
                Divider()
                supplierList(r.suppliers.prefix(4))
                footer(r)
            } else {
                emptyState
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("BQ11 · Desempeño por proveedor")
                .font(.subheadline.weight(.semibold))
            Text("Órdenes de compra agregadas por proveedor (offline-first)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func overall(_ r: SupplierPerformanceReport) -> some View {
        HStack(spacing: 20) {
            metricBlock(
                label: "Valor comprometido",
                value: r.totalCommitted.compactCurrency,
                color: .green
            )
            metricBlock(
                label: "Órdenes",
                value: "\(r.totalOrders)",
                color: .primary
            )
            metricBlock(
                label: "Sin sincronizar",
                value: "\(r.pendingSyncOrders)",
                color: r.pendingSyncOrders > 0 ? .orange : .green
            )
        }
    }

    private func metricBlock(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func supplierList(_ rows: ArraySlice<SupplierOrderStats>) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(rows)) { s in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.supplierName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text("\(s.orderCount) orden\(s.orderCount == 1 ? "" : "es") · \(s.itemCount) uds"
                             + (s.pendingSyncCount > 0 ? " · \(s.pendingSyncCount) pend." : ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(s.totalCommitted.compactCurrency)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                }
            }
        }
    }

    private func footer(_ r: SupplierPerformanceReport) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.caption2)
            Text(String(format: "%d proveedor%@ · agregado en %.1f ms",
                        r.suppliers.count,
                        r.suppliers.count == 1 ? "" : "es",
                        r.durationMs))
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "doc.badge.plus")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Crea órdenes de compra (Inicio → Herramientas) para ver esta BQ.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView("Agregando órdenes…").font(.footnote)
            Spacer()
        }
        .padding(.vertical, 24)
    }
}
