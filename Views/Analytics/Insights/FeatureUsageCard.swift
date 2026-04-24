import SwiftUI

/// BQ8 
struct FeatureUsageCard: View {
    let summary: FeatureUsageSummary?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if isLoading && summary == nil {
                HStack { Spacer(); ProgressView().scaleEffect(0.7); Spacer() }
            } else if let s = summary, !s.rows.isEmpty {
                rows(s.rows)
                footer(s)
            } else if summary != nil {
                empty
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("BQ8 · Features analíticas más consultadas por semana")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.inkBlack)
            Text("Agregación off-main por feature × semana ISO")
                .font(.caption2)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    private func rows(_ items: [FeatureUsageRow]) -> some View {
        VStack(spacing: 10) {
            ForEach(items.prefix(6)) { row in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.feature)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.inkBlack)
                        Text("\(row.weeklyCounts.count) semanas con actividad")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Spacer()
                    Text("\(row.totalAccesses)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.freshSky)
                }
            }
        }
    }

    private func footer(_ s: FeatureUsageSummary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.doc.horizontal").font(.caption2)
            Text(String(format: "Calculado en %.1f ms", s.durationMs))
                .font(.caption2)
        }
        .foregroundColor(AppColors.textTertiary)
    }

    private var empty: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "eye.slash")
                    .font(.title2)
                    .foregroundColor(AppColors.textTertiary)
                Text("No hay aún eventos de features registradas.")
                    .font(.footnote)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
}
