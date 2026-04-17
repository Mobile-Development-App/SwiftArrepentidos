import SwiftUI

struct LanguageSettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private let languages: [(code: String, name: String, flag: String)] = [
        ("es", "Español", "\u{1F1E8}\u{1F1F4}"),
        ("en", "English", "\u{1F1FA}\u{1F1F8}")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ForEach(languages, id: \.code) { language in
                    Button(action: {
                        settingsViewModel.selectedLanguage = language.code
                        HapticManager.selection()
                    }) {
                        HStack(spacing: 14) {
                            Text(language.flag)
                                .font(.system(size: 28))

                            Text(language.name)
                                .font(AppTypography.bodyFont)
                                .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

                            Spacer()

                            if settingsViewModel.selectedLanguage == language.code {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.primary)
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(16)
                        .background(
                            settingsViewModel.selectedLanguage == language.code ?
                                AppColors.primary.opacity(0.08) :
                                (colorScheme == .dark ? AppColors.darkSurface : AppColors.surface)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    settingsViewModel.selectedLanguage == language.code ?
                                        AppColors.primary.opacity(0.3) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Idioma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
