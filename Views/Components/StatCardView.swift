import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    var trend: Double? = nil
    var trendLabel: String? = nil

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Spacer()

                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(String(format: "%.1f%%", abs(trend)))
                            .font(AppTypography.caption2Font)
                    }
                    .foregroundColor(trend >= 0 ? AppColors.success : AppColors.error)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        (trend >= 0 ? AppColors.success : AppColors.error).opacity(0.1)
                    )
                    .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(AppTypography.title2Font)
                    .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

                Text(title)
                    .font(AppTypography.captionFont)
                    .foregroundColor(colorScheme == .dark ? AppColors.darkTextSecondary : AppColors.textSecondary)
            }
        }
        .padding(14)
        .cardStyle()
    }
}
