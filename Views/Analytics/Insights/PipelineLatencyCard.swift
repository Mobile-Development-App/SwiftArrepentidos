import SwiftUI

/// BQ1 
struct PipelineLatencyCard: View {
    let summary: LatencySummary?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if isLoading && summary == nil {
                loadingRow
            } else if let s = summary, s.totalSamples > 0 {
                overall(s)
                Divider()
                stageRows(s.stages)
                footer(s)
            } else if summary != nil {
                emptyState
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("BQ1 · Latencia promedio del pipeline")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.inkBlack)
                Text("ingestion → storage → processing → computation")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            if isLoading { ProgressView().scaleEffect(0.7) }
        }
    }

    private func overall(_ s: LatencySummary) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Promedio global")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                Text(String(format: "%.1f ms", s.overallAverageMs))
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColors.freshSky)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Muestras (30 días)")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                Text("\(s.totalSamples)")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColors.inkBlack)
            }
            Spacer()
        }
    }

    private func stageRows(_ stats: [StageStat]) -> some View {
        VStack(spacing: 10) {
            ForEach(stats) { stat in
                HStack {
                    Text(stat.stage.rawValue.capitalized)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.inkBlack)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f ms", stat.averageMs))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.inkBlack)
                        Text("\(stat.count) muestras")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
    }

    private func footer(_ s: LatencySummary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.caption2)
            Text(String(format: "Calculado en %.1f ms (off-main)", s.durationMs))
                .font(.caption2)
        }
        .foregroundColor(AppColors.textTertiary)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "gauge.with.needle")
                    .font(.title2)
                    .foregroundColor(AppColors.textTertiary)
                Text("Aún no hay muestras de latencia.")
                    .font(.footnote)
                    .foregroundColor(AppColors.textTertiary)
                Text("Crea o edita un producto para capturar samples.")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView("Agregando samples…")
                .font(.footnote)
            Spacer()
        }
        .padding(.vertical, 24)
    }
}
