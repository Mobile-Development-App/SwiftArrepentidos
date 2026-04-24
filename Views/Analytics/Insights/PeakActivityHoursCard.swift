import SwiftUI
import Charts

/// BQ6 — At what hour of day does the user add products most often?
///
/// Rendered as a 24-bucket bar chart of `.productCreated` events over the
/// last 30 days. Histogram is computed on a detached task by
/// `PeakActivityAnalyzer`.
struct PeakActivityHoursCard: View {
    let summary: PeakActivitySummary?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if isLoading && summary == nil {
                loadingRow
            } else if let s = summary, s.totalEvents > 0 {
                metrics(s)
                chart(s)
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

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("BQ6 · Hora pico para agregar productos")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.inkBlack)
                Text("Histograma en background (Task.detached)")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            if isLoading {
                ProgressView().scaleEffect(0.7)
            }
        }
    }

    private func metrics(_ s: PeakActivitySummary) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hora pico")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                Text(s.peakHour.map { String(format: "%02d:00", $0) } ?? "—")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColors.freshSky)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Eventos (\(s.windowDays) días)")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                Text("\(s.totalEvents)")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColors.inkBlack)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Promedio/hora activa")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                Text(String(format: "%.1f", s.averagePerActiveHour))
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColors.teaGreen)
            }
            Spacer(minLength: 0)
        }
    }

    private func chart(_ s: PeakActivitySummary) -> some View {
        Chart(s.buckets) { bucket in
            BarMark(
                x: .value("Hora", bucket.hour),
                y: .value("Eventos", bucket.count)
            )
            .foregroundStyle(
                s.peakHour == bucket.hour
                    ? AppColors.freshSky
                    : AppColors.freshSky.opacity(0.35)
            )
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: stride(from: 0, through: 23, by: 3).map { $0 }) { value in
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text(String(format: "%02d", hour))
                            .font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel { if let i = value.as(Int.self) { Text("\(i)").font(.caption2) } }
                AxisGridLine()
            }
        }
        .frame(height: 180)
    }

    private func footer(_ s: PeakActivitySummary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath").font(.caption2)
            Text(String(format: "Calculado en %.1f ms · ventana %d días",
                        s.durationMs, s.windowDays))
                .font(.caption2)
        }
        .foregroundColor(AppColors.textTertiary)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundColor(AppColors.textTertiary)
                Text("Aún no hay eventos registrados.")
                    .font(.footnote)
                    .foregroundColor(AppColors.textTertiary)
                Text("Agrega un producto para empezar a llenar el histograma.")
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
            ProgressView("Analizando eventos…")
                .font(.footnote)
            Spacer()
        }
        .padding(.vertical, 24)
    }
}
