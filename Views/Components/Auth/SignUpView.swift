import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Crear Cuenta")
                            .font(AppTypography.titleFont)

                        Text("Completa tus datos para comenzar")
                            .font(AppTypography.calloutFont)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 18) {
                        // Full name
                        formField(
                            label: "Nombre completo",
                            icon: "person",
                            placeholder: "Tu nombre completo",
                            text: $authViewModel.signUpName
                        )

                        // Email
                        formField(
                            label: "Correo electrónico",
                            icon: "envelope",
                            placeholder: "tu@correo.com",
                            text: $authViewModel.signUpEmail,
                            keyboardType: .emailAddress
                        )

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Contraseña")
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.textSecondary)

                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(AppColors.textTertiary)
                                if showPassword {
                                    TextField("Mínimo 8 caracteres", text: $authViewModel.signUpPassword)
                                } else {
                                    SecureField("Mínimo 8 caracteres", text: $authViewModel.signUpPassword)
                                }
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(AppColors.textTertiary)
                                }
                            }
                            .padding(14)
                            .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            if !authViewModel.signUpPassword.isEmpty && !authViewModel.passwordLengthValid {
                                Text("La contraseña debe tener al menos 8 caracteres")
                                    .font(AppTypography.caption2Font)
                                    .foregroundColor(AppColors.error)
                            }
                        }

                        // Confirm password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirmar contraseña")
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.textSecondary)

                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(AppColors.textTertiary)
                                SecureField("Repite tu contraseña", text: $authViewModel.signUpConfirmPassword)
                            }
                            .padding(14)
                            .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            if !authViewModel.signUpConfirmPassword.isEmpty && !authViewModel.passwordsMatch {
                                Text("Las contraseñas no coinciden")
                                    .font(AppTypography.caption2Font)
                                    .foregroundColor(AppColors.error)
                            }
                        }

                        // Store name
                        formField(
                            label: "Nombre de tu tienda",
                            icon: "storefront",
                            placeholder: "Mi Tienda",
                            text: $authViewModel.signUpStoreName
                        )

                        // Terms
                        HStack(alignment: .top, spacing: 10) {
                            Button(action: {
                                authViewModel.signUpAcceptedTerms.toggle()
                                HapticManager.impact(.light)
                            }) {
                                Image(systemName: authViewModel.signUpAcceptedTerms ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 22))
                                    .foregroundColor(authViewModel.signUpAcceptedTerms ? AppColors.primary : AppColors.textTertiary)
                            }

                            Text("Acepto los términos y condiciones y la política de privacidad")
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        // Error
                        if let error = authViewModel.signUpError {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(AppColors.error)
                                Text(error)
                                    .font(AppTypography.captionFont)
                                    .foregroundColor(AppColors.error)
                            }
                            .padding(12)
                            .background(AppColors.error.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Sign up button
                        Button(action: {
                            hideKeyboard()
                            authViewModel.signUp()
                        }) {
                            if authViewModel.isSigningUp {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Crear Cuenta")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!authViewModel.isSignUpValid || authViewModel.isSigningUp)
                    }
                    .padding(.horizontal, 24)

                    // Login link
                    HStack {
                        Text("¿Ya tienes cuenta?")
                            .font(AppTypography.calloutFont)
                            .foregroundColor(AppColors.textSecondary)
                        Button("Iniciar sesión") {
                            dismiss()
                        }
                        .font(AppTypography.calloutFont)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                    }
                    .padding(.bottom, 20)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func formField(label: String, icon: String, placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppTypography.captionFont)
                .foregroundColor(AppColors.textSecondary)

            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppColors.textTertiary)
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                    .autocorrectionDisabled()
            }
            .padding(14)
            .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
