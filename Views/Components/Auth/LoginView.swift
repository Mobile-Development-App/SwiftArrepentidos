import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var showPassword = false

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)

                    // Logo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 36))
                                .foregroundColor(AppColors.primary)
                        }

                        Text("InventarIA")
                            .font(AppTypography.largeTitleFont)
                            .foregroundColor(colorScheme == .dark ? AppColors.darkTextPrimary : AppColors.textPrimary)

                        Text("Gestión inteligente de inventario")
                            .font(AppTypography.calloutFont)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    // Form
                    VStack(spacing: 20) {
                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Correo electrónico")
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.textSecondary)

                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(AppColors.textTertiary)
                                TextField("tu@correo.com", text: $authViewModel.loginEmail)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            }
                            .padding(14)
                            .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Contraseña")
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.textSecondary)

                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(AppColors.textTertiary)

                                if showPassword {
                                    TextField("••••••••", text: $authViewModel.loginPassword)
                                        .textContentType(.password)
                                } else {
                                    SecureField("••••••••", text: $authViewModel.loginPassword)
                                        .textContentType(.password)
                                }

                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(AppColors.textTertiary)
                                }
                            }
                            .padding(14)
                            .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Forgot password
                        HStack {
                            Spacer()
                            Button("¿Olvidaste tu contraseña?") {
                                showForgotPassword = true
                            }
                            .font(AppTypography.captionFont)
                            .foregroundColor(AppColors.primary)
                        }

                        // Error message
                        if let error = authViewModel.loginError {
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

                        // Login button
                        Button(action: {
                            hideKeyboard()
                            authViewModel.login()
                        }) {
                            if authViewModel.isLoggingIn {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Iniciar Sesión")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!authViewModel.isLoginValid || authViewModel.isLoggingIn)
                    }
                    .padding(.horizontal, 24)

                    // Sign up link
                    HStack {
                        Text("¿No tienes cuenta?")
                            .font(AppTypography.calloutFont)
                            .foregroundColor(AppColors.textSecondary)
                        Button("Crear cuenta") {
                            showSignUp = true
                        }
                        .font(AppTypography.calloutFont)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                    }

                    Spacer().frame(height: 20)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
}
