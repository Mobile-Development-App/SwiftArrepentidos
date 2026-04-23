import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme

    @State private var showSecurity = false
    @State private var showStoreManagement = false
    @State private var showTeamMembers = false
    @State private var showHelpCenter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileCard

                    settingsSection(title: "Preferencias") {
                        settingsToggle(
                            icon: "moon.fill",
                            title: "Modo Oscuro",
                            isOn: $settingsViewModel.isDarkMode,
                            color: AppColors.primary
                        )

                        settingsToggle(
                            icon: "bell.fill",
                            title: "Notificaciones",
                            isOn: $settingsViewModel.notificationsEnabled,
                            color: AppColors.warning
                        )

                        disabledSettingRow(icon: "globe", title: "Idioma", value: "Español (próximamente)", color: AppColors.info)
                    }

                    settingsSection(title: "Cuenta") {
                        settingsNavRow(icon: "storefront", title: "Gestión de Tiendas", color: AppColors.accent) {
                            showStoreManagement = true
                        }

                        settingsNavRow(icon: "person.2.fill", title: "Miembros del Equipo", color: AppColors.secondary) {
                            showTeamMembers = true
                        }

                        settingsNavRow(icon: "shield.fill", title: "Seguridad", color: AppColors.success) {
                            showSecurity = true
                        }
                    }

                    settingsSection(title: "Soporte") {
                        settingsNavRow(icon: "questionmark.circle.fill", title: "Centro de Ayuda", color: AppColors.info) {
                            showHelpCenter = true
                        }

                        disabledSettingRow(icon: "doc.text.fill", title: "Términos y Condiciones", value: "Próximamente", color: AppColors.textSecondary)
                    }

                    Button(action: {
                        settingsViewModel.showingLogoutConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Cerrar Sesión")
                        }
                        .font(AppTypography.headlineFont)
                        .foregroundColor(AppColors.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Text("InventarIA v\(settingsViewModel.appVersion) (\(settingsViewModel.buildNumber))")
                        .font(AppTypography.caption2Font)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.bottom, 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(colorScheme == .dark ? AppColors.darkBackground : AppColors.background)
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSecurity) {
                SecurityView()
            }
            .sheet(isPresented: $showStoreManagement) {
                StoreManagementView()
            }
            .sheet(isPresented: $showTeamMembers) {
                TeamMembersView()
            }
            .sheet(isPresented: $showHelpCenter) {
                HelpCenterView()
            }
            .alert("Cerrar Sesión", isPresented: $settingsViewModel.showingLogoutConfirmation) {
                Button("Cancelar", role: .cancel) {}
                Button("Cerrar Sesión", role: .destructive) {
                    authViewModel.logout()
                }
            } message: {
                Text("¿Estás seguro de que deseas cerrar tu sesión?")
            }
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 56, height: 56)
                Text(authViewModel.currentUser?.initials ?? "??")
                    .font(AppTypography.title3Font)
                    .foregroundColor(AppColors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(authViewModel.currentUser?.fullName ?? "Usuario")
                    .font(AppTypography.headlineFont)
                    .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

                Text(authViewModel.currentUser?.storeName ?? "Mi Tienda")
                    .font(AppTypography.captionFont)
                    .foregroundColor(AppColors.textSecondary)

                Text(authViewModel.currentUser?.email ?? "")
                    .font(AppTypography.caption2Font)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(16)
        .cardStyle()
    }

    @ViewBuilder
    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .cardStyle()
        }
    }

    private func settingsToggle(icon: String, title: String, isOn: Binding<Bool>, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(AppTypography.bodyFont)
                .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

            Spacer()

            Toggle("", isOn: isOn)
                .tint(AppColors.primary)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func settingsNavRow(icon: String, title: String, value: String? = nil, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(AppTypography.bodyFont)
                    .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

                Spacer()

                if let value = value {
                    Text(value)
                        .font(AppTypography.captionFont)
                        .foregroundColor(AppColors.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func disabledSettingRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color.opacity(0.5))
                .frame(width: 32, height: 32)
                .background(color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(AppTypography.bodyFont)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
