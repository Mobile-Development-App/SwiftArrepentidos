import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// StockAccuracyCard — Sprint 4. Card de BQ9 en el dashboard de Business
// Questions. Muestra la exactitud del inventario calculada a partir de los
// conteos físicos completados.
// ─────────────────────────────────────────────────────────────────────────────

struct StockAccuracyCard: View {
    let summary: StockCountSummary?
    let sessionsAnalyzed: Int
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if isLoading && summary == nil {
                loadingRow
            } else if let s = summary, s.countedItems > 0 {
                overall(s)
                Divider()
                categoryList(s.perCategory.prefix(4))
                footer(s)
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
            Text("BQ9 · Exactitud del inventario")
                .font(.subheadline.weight(.semibold))
            Text("Reconciliación concurrente conteo físico vs. sistema (TaskGroup)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func overall(_ s: StockCountSummary) -> some View {
        HStack(spacing: 20) {
            metricBlock(
                label: "Exactitud global",
                value: String(format: "%.0f%%", s.overallAccuracyPct),
                color: accuracyColor(s.overallAccuracyPct)
            )
            metricBlock(
                label: "Productos contados",
                value: "\(s.countedItems)",
                color: .primary
            )
            metricBlock(
                label: "Con discrepancia",
                value: "\(s.itemsWithDiscrepancy)",
                color: s.itemsWithDiscrepancy > 0 ? .orange : .green
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

    private func categoryList(_ rows: ArraySlice<CategoryAccuracy>) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(rows)) { cat in
                HStack {
                    Image(systemName: cat.category.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cat.category.rawValue)
                            .font(.subheadline.weight(.medium))
                        Text("\(cat.countedItems) contados · \(cat.itemsWithDiscrepancy) con diferencia")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%%", cat.accuracyPct))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(accuracyColor(cat.accuracyPct))
                }
            }
        }
    }

    private func footer(_ s: StockCountSummary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.caption2)
            Text(String(format: "%d sesión%@ analizada%@ · agregado en %.1f ms",
                        sessionsAnalyzed,
                        sessionsAnalyzed == 1 ? "" : "es",
                        sessionsAnalyzed == 1 ? "" : "s",
                        s.durationMs))
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Realiza un conteo físico (Inicio → Herramientas) para ver esta BQ.")
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
            ProgressView("Reconciliando conteos…").font(.footnote)
            Spacer()
        }
        .padding(.vertical, 24)
    }

    private func accuracyColor(_ pct: Double) -> Color {
        if pct >= 95 { return .green }
        if pct >= 80 { return .orange }
        return .red
    }
}
