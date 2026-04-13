import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer().frame(height: 40)

                if authViewModel.forgotPasswordSent {
                    // Success state
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(AppColors.success.opacity(0.1))
                                .frame(width: 100, height: 100)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.success)
                        }

                        Text("Correo Enviado")
                            .font(AppTypography.titleFont)

                        Text("Hemos enviado instrucciones para restablecer tu contraseña a \(authViewModel.forgotPasswordEmail)")
                            .font(AppTypography.bodyFont)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button(action: {
                            authViewModel.forgotPasswordSent = false
                            authViewModel.forgotPasswordEmail = ""
                            dismiss()
                        }) {
                            Text("Volver al inicio de sesión")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 24)
                    }
                } else {
                    // Form state
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 36))
                                .foregroundColor(AppColors.primary)
                        }

                        VStack(spacing: 8) {
                            Text("Recuperar Contraseña")
                                .font(AppTypography.titleFont)

                            Text("Ingresa tu correo electrónico y te enviaremos instrucciones para restablecer tu contraseña")
                                .font(AppTypography.calloutFont)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Correo electrónico")
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.textSecondary)

                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(AppColors.textTertiary)
                                TextField("tu@correo.com", text: $authViewModel.forgotPasswordEmail)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            }
                            .padding(14)
                            .background(colorScheme == .dark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 24)

                        if let error = authViewModel.forgotPasswordError {
                            Text(error)
                                .font(AppTypography.captionFont)
                                .foregroundColor(AppColors.error)
                        }

                        Button(action: {
                            hideKeyboard()
                            authViewModel.sendPasswordReset()
                        }) {
                            Text("Enviar Instrucciones")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 24)
                        .disabled(authViewModel.forgotPasswordEmail.isEmpty)
                    }
                }

                Spacer()
            }
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
}
