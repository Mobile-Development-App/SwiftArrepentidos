import SwiftUI

struct ExpirationActionCard: View {
    let dashboard: ExpirationInsightsDashboard?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if isLoading && dashboard == nil {
                loadingRow
            } else if let d = dashboard, d.totalAtRisk > 0 {
                kpiRow(d)
                Divider()
                ForEach(ExpirationUrgency.allCases, id: \.self) { urgency in
                    let rows = d.advice(for: urgency)
                    if !rows.isEmpty {
                        section(title: urgency, rows: rows)
                    }
                }
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
            Text("BQ4 · Productos próximos a vencer · acciones sugeridas")
                .font(.subheadline.weight(.semibold))
            Text("Clasificación concurrente por urgencia y margen")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func kpiRow(_ d: ExpirationInsightsDashboard) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Productos en riesgo")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(d.totalAtRisk)")
                    .font(.title3.weight(.bold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Unidades afectadas")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(d.totalUnitsAtRisk)")
                    .font(.title3.weight(.bold))
            }
            Spacer()
        }
    }

    private func section(title urgency: ExpirationUrgency,
                         rows: [ExpirationAdvice]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: urgency.systemIcon)
                    .foregroundColor(urgency.color)
                Text(urgency.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(urgency.color)
                Spacer()
                Text("\(rows.count)")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(urgency.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(urgency.color.opacity(0.12))
                    .clipShape(Capsule())
            }
            VStack(spacing: 8) {
                ForEach(rows.prefix(4)) { row in
                    adviceRow(row)
                }
                if rows.count > 4 {
                    Text("+\(rows.count - 4) más en esta categoría")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func adviceRow(_ row: ExpirationAdvice) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: row.category.icon)
                .foregroundColor(row.urgency.color)
                .frame(width: 28, height: 28)
                .background(row.urgency.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(row.productName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(row.rationale)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: row.action.systemIcon)
                        .font(.caption2)
                    Text(row.action.label)
                        .font(.caption2.weight(.semibold))
                }
                .foregroundColor(row.urgency.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(row.urgency.color.opacity(0.1))
                .clipShape(Capsule())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.daysRemaining < 0
                     ? "Vencido"
                     : "\(row.daysRemaining) d")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(row.urgency.color)
                Text("\(row.quantity) uds")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func footer(_ d: ExpirationInsightsDashboard) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath").font(.caption2)
            Text(String(format: "Calculado en %.1f ms", d.durationMs))
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Ningún producto está dentro de la ventana de 30 días.")
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
            ProgressView("Clasificando productos…").font(.footnote)
            Spacer()
        }
        .padding(.vertical, 24)
    }
}
