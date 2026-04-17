import SwiftUI

struct SecurityView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    securityOverview

                    credentialsSection

                    actionsSection

                    tipsSection

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Seguridad")
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

    private var securityOverview: some View {
        HStack(spacing: 14) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 32))
                .foregroundColor(AppColors.success)

            VStack(alignment: .leading, spacing: 4) {
                Text("Seguridad de la Cuenta")
                    .font(AppTypography.headlineFont)
                Text("Tu cuenta tiene un nivel de seguridad bueno")
                    .font(AppTypography.captionFont)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }

    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Credenciales")
                .font(AppTypography.headlineFont)

            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(AppColors.textTertiary)
                Text(authViewModel.currentUser?.email ?? "")
                    .font(AppTypography.bodyFont)
                Spacer()
                BadgeView(text: "Verificado", style: .success)
            }
            .padding(14)
            .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Image(systemName: "lock")
                    .foregroundColor(AppColors.textTertiary)
                Text("••••••••")
                    .font(AppTypography.bodyFont)
                Spacer()
                BadgeView(text: "Segura", style: .success)
            }
            .padding(14)
            .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .cardStyle()
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acciones de Seguridad")
                .font(AppTypography.headlineFont)

            securityAction(icon: "key.fill", title: "Cambiar Contraseña", color: AppColors.primary)
            securityAction(icon: "lock.shield.fill", title: "Autenticación de 2 Factores", color: AppColors.accent)
            securityAction(icon: "clock.arrow.circlepath", title: "Historial de Acceso", color: AppColors.info)
        }
        .padding(16)
        .cardStyle()
    }

    private func securityAction(icon: String, title: String, color: Color) -> some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(AppTypography.calloutFont)
                    .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, 4)
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppColors.warning)
                Text("Consejos de Seguridad")
                    .font(AppTypography.headlineFont)
            }

            VStack(alignment: .leading, spacing: 8) {
                tipRow("Usa una contraseña de al menos 8 caracteres")
                tipRow("Activa la autenticación de 2 factores")
                tipRow("No compartas tus credenciales de acceso")
                tipRow("Revisa periódicamente el historial de acceso")
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(AppColors.success)
            Text(text)
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}
