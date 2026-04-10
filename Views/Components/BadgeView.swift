import SwiftUI

struct BadgeView: View {
    let text: String
    var style: BadgeStyle = .default

    enum BadgeStyle {
        case `default`, success, warning, destructive, info, secondary

        var backgroundColor: Color {
            switch self {
            case .default: return AppColors.primary.opacity(0.12)
            case .success: return AppColors.success.opacity(0.12)
            case .warning: return AppColors.warning.opacity(0.12)
            case .destructive: return AppColors.error.opacity(0.12)
            case .info: return AppColors.info.opacity(0.12)
            case .secondary: return AppColors.textSecondary.opacity(0.12)
            }
        }

        var textColor: Color {
            switch self {
            case .default: return AppColors.primary
            case .success: return AppColors.success
            case .warning: return AppColors.warning
            case .destructive: return AppColors.error
            case .info: return AppColors.info
            case .secondary: return AppColors.textSecondary
            }
        }
    }

    var body: some View {
        Text(text)
            .font(AppTypography.caption2Font)
            .fontWeight(.semibold)
            .foregroundColor(style.textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(style.backgroundColor)
            .clipShape(Capsule())
    }
}

//badge basics
struct StockBadge: View {
    let status: StockStatus

    var badgeStyle: BadgeView.BadgeStyle {
        switch status {
        case .inStock: return .success
        case .lowStock: return .warning
        case .outOfStock: return .destructive
        }
    }

    var body: some View {
        BadgeView(text: status.rawValue, style: badgeStyle)
    }
}
