import SwiftUI

struct AlertCardView: View {
    let alert: InventoryAlert
    var onTap: (() -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme

    var alertColor: Color {
        switch alert.type {
        case .lowStock, .expiringSoon: return AppColors.warning
        case .outOfStock, .expired: return AppColors.error
        case .priceChange: return AppColors.info
        case .newProduct, .restock: return AppColors.success
        }
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: alert.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(alertColor)
                    .frame(width: 36, height: 36)
                    .background(alertColor.opacity(0.12))
                    .clipShape(Circle())

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(alert.title)
                            .font(AppTypography.calloutFont)
                            .fontWeight(.semibold)
                            .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

                        Spacer()

                        Text(alert.relativeTime)
                            .font(AppTypography.caption2Font)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Text(alert.message)
                        .font(AppTypography.captionFont)
                        .foregroundColor(colorScheme == .dark ? AppColors.darkTextSecondary : AppColors.textSecondary)
                        .lineLimit(2)
                }

                // Unread indicator
                if !alert.isRead {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(alert.isRead ?
                          (colorScheme == .dark ? AppColors.darkSurface : AppColors.surface) :
                            (colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.primary.opacity(0.03)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(alert.isRead ? Color.clear : AppColors.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
