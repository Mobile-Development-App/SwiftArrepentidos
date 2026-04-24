import SwiftUI

/// BQ7 barcode scan vs manual entry accuracy
struct ScanAccuracyCard: View {
    let summary: ScanAccuracySummary?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if isLoading && summary == nil {
                HStack { Spacer(); ProgressView().scaleEffect(0.7); Spacer() }
            } else if let s = summary, (s.cameraAttempts + s.manualAttempts) > 0 {
                comparison(s)
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
            Text("BQ7 · Scan con cámara vs entrada manual")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.inkBlack)
            Text("Precisión de reconocimiento · últimos 30 días")
                .font(.caption2)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    private func comparison(_ s: ScanAccuracySummary) -> some View {
        HStack(spacing: 20) {
            accuracyBlock(
                title: "Cámara",
                accuracy: s.cameraAccuracy,
                attempts: s.cameraAttempts,
                tint: AppColors.freshSky
            )
            accuracyBlock(
                title: "Manual",
                accuracy: s.manualAccuracy,
                attempts: s.manualAttempts,
                tint: AppColors.teaGreen
            )
        }
    }

    private func accuracyBlock(title: String, accuracy: Double, attempts: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
            Text(String(format: "%.0f%%", accuracy * 100))
                .font(.title2.weight(.bold))
                .foregroundColor(tint)
            ProgressView(value: accuracy)
                .tint(tint)
            Text("\(attempts) intentos")
                .font(.caption2)
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func footer(_ s: ScanAccuracySummary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "speedometer").font(.caption2)
            Text(String(format: "Calculado en %.1f ms", s.durationMs))
                .font(.caption2)
        }
        .foregroundColor(AppColors.textTertiary)
    }

    private var empty: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "barcode.viewfinder")
                    .font(.title2)
                    .foregroundColor(AppColors.textTertiary)
                Text("Sin intentos de scan registrados todavía.")
                    .font(.footnote)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
}
