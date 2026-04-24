import SwiftUI

struct RestockCyclesCard: View {
    let dashboard: RestockCyclesDashboard?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if isLoading && dashboard == nil {
                loadingRow
            } else if let d = dashboard, d.totalCycles > 0 {
                overall(d)
                Divider()
                list(d.products.filter { $0.cycles > 0 }.prefix(4))
                footer(d)
            } else if dashboard != nil {
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
            Text("BQ3 · Tiempo promedio de reposición")
                .font(.subheadline.weight(.semibold))
            Text("Agregación paralela por producto (TaskGroup)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func overall(_ d: RestockCyclesDashboard) -> some View {
        HStack(spacing: 20) {
            metricBlock(
                label: "Promedio global",
                value: String(format: "%.1f días", d.overallAverageDays),
                color: .orange
            )
            metricBlock(
                label: "Ciclos registrados",
                value: "\(d.totalCycles)",
                color: .primary
            )
            metricBlock(
                label: "Más lento",
                value: String(format: "%.1f días", d.longestCycleDays),
                color: .red
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

    private func list(_ stats: ArraySlice<ProductRestockStats>) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(stats)) { row in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.productName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text("\(row.cycles) ciclo\(row.cycles == 1 ? "" : "s") · "
                             + (row.lastRestockAt.map { "último " + relativeTime(from: $0) } ?? "sin fecha"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f días", row.averageDays))
                            .font(.subheadline.weight(.semibold))
                        Text(String(format: "min %.1f · max %.1f",
                                    row.minDays, row.maxDays))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func footer(_ d: RestockCyclesDashboard) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.caption2)
            Text(String(format: "Agregado en %.1f ms · %@",
                        d.durationMs, relativeTime(from: d.computedAt)))
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Aún no hay ciclos de reposición registrados.")
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
            ProgressView("Calculando ciclos…").font(.footnote)
            Spacer()
        }
        .padding(.vertical, 24)
    }

    private func relativeTime(from date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
