import SwiftUI

/// BQ5 
struct PeakScreensCard: View {
    let summary: PeakScreensSummary?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if isLoading && summary == nil {
                loading
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
            Text("BQ5 · Pantallas con más tráfico por hora pico")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.inkBlack)
            Text("Últimos 30 días · histograma por pantalla (isolate)")
                .font(.caption2)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    private func rows(_ items: [ScreenPeak]) -> some View {
        VStack(spacing: 10) {
            ForEach(items.prefix(6)) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.screen)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.inkBlack)
                        Text("pico a las \(String(format: "%02d:00", item.peakHour))")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(item.total)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.freshSky)
                        Text("visitas")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
    }

    private func footer(_ s: PeakScreensSummary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath").font(.caption2)
            Text(String(format: "Calculado en %.1f ms", s.durationMs))
                .font(.caption2)
        }
        .foregroundColor(AppColors.textTertiary)
    }

    private var empty: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "rectangle.stack")
                    .font(.title2)
                    .foregroundColor(AppColors.textTertiary)
                Text("Aún no se registra navegación entre pantallas.")
                    .font(.footnote)
                    .foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    private var loading: some View {
        HStack { Spacer(); ProgressView("Analizando…").font(.footnote); Spacer() }
            .padding(.vertical, 24)
    }
}
