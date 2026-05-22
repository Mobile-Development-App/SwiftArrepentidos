import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// WasteReportCard — Sprint 4. Card de BQ10 (Santiago) en el dashboard de
// Business Questions. Resume el valor de mermas por causa y por categoría.
// ─────────────────────────────────────────────────────────────────────────────

struct WasteReportCard: View {
    let report: WasteReport?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if isLoading && report == nil {
                loadingRow
            } else if let r = report, r.totalEvents > 0 {
                overall(r)
                Divider()
                reasonList(r.byReason.prefix(4))
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
            Text("BQ10 · Valor de mermas")
                .font(.subheadline.weight(.semibold))
            Text("Reporte cacheado (cache-aside + TTL + invalidación)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func overall(_ r: WasteReport) -> some View {
        HStack(spacing: 20) {
            metricBlock(
                label: "Valor perdido",
                value: r.totalValueLost.compactCurrency,
                color: .red
            )
            metricBlock(
                label: "Unidades",
                value: "\(r.totalUnitsLost)",
                color: .primary
            )
            metricBlock(
                label: "Eventos",
                value: "\(r.totalEvents)",
                color: .orange
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

    private func reasonList(_ rows: ArraySlice<WasteReasonBreakdown>) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(rows)) { row in
                HStack {
                    Image(systemName: row.reason.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 22)
                    Text(row.reason.rawValue)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(row.unitsLost) uds")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(row.valueLost.compactCurrency)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)
                }
            }
        }
    }

    private func footer(_ r: WasteReport) -> some View {
        HStack(spacing: 4) {
            Image(systemName: r.fromCache ? "bolt.fill" : "function").font(.caption2)
            Text(r.fromCache
                 ? "Servido desde caché · ventana \(r.windowDays) días"
                 : String(format: "Computado en %.1f ms · ventana %d días",
                          r.durationMs, r.windowDays))
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "trash.slash")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Registra mermas (Inicio → Herramientas) para ver esta BQ.")
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
            ProgressView("Calculando mermas…").font(.footnote)
            Spacer()
        }
        .padding(.vertical, 24)
    }
}
