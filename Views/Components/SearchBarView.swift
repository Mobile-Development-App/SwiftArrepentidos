import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Buscar productos..."

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)
                .font(.system(size: 16))

            TextField(placeholder, text: $text)
                .font(AppTypography.bodyFont)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button(action: {
                    text = ""
                    HapticManager.impact(.light)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
