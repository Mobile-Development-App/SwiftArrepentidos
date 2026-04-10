import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)

            Text(title)
                .font(AppTypography.title3Font)
                .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

            Text(description)
                .font(AppTypography.bodyFont)
                .foregroundColor(colorScheme == .dark ? AppColors.darkTextSecondary : AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 60)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
