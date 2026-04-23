import SwiftUI
import Combine

/// AuthViewModel - MVVM ViewModel for authentication.
/// Uses Firebase Auth + backend REST API via AuthRepository.
/// Falls back to cached user for offline launch.
@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var hasCompletedOnboarding: Bool
    @Published var currentUser: User?

    // Login
    @Published var loginEmail = ""
    @Published var loginPassword = ""
    @Published var loginError: String?
    @Published var isLoggingIn = false

    // Sign Up
    @Published var signUpName = ""
    @Published var signUpEmail = ""
    @Published var signUpPassword = ""
    @Published var signUpConfirmPassword = ""
    @Published var signUpStoreName = ""
    @Published var signUpAcceptedTerms = false
    @Published var signUpError: String?
    @Published var isSigningUp = false

    // Forgot Password
    @Published var forgotPasswordEmail = ""
    @Published var forgotPasswordSent = false
    @Published var forgotPasswordError: String?

    // Rate limiting
    private var lastForgotPasswordRequest: Date?
    private let forgotPasswordCooldown: TimeInterval = 60

    private let authRepository = AuthRepository()
    private let persistence = PersistenceService.shared
    private var tokenExpirationObserver: Any?

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if let savedUser = persistence.loadUser() {
            currentUser = savedUser
            isAuthenticated = true

            Task { [weak self] in
                if let user = await self?.authRepository.restoreSession() {
                    self?.currentUser = user
                }
            }
        }

        tokenExpirationObserver = NotificationCenter.default.addObserver(
            forName: .authTokenExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleTokenExpired()
        }
    }

    deinit {
        if let observer = tokenExpirationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Validation

    /// Valida email con regex real (no solo "contains @")
    private func isValidEmail(_ s: String) -> Bool {
        let e = s.trimmingCharacters(in: .whitespaces)
        guard e.count >= 5, e.count <= 254 else { return false }
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return e.range(of: regex, options: .regularExpression) != nil
    }

    /// Valida password: 8-128 chars, sin espacios, sin emojis/unicode
    private func isValidPassword(_ p: String) -> Bool {
        guard p.count >= 8, p.count <= 128 else { return false }
        guard p.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return false }
        guard p.canBeConverted(to: .ascii) else { return false }
        return true
    }

    /// Valida nombres (persona, tienda): 2-100 chars después de trim
    private func isValidName(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 100
    }

    var isLoginValid: Bool {
        isValidEmail(loginEmail) && !loginPassword.isEmpty && loginPassword.count <= 128
    }

    var isSignUpValid: Bool {
        isValidName(signUpName) &&
        isValidEmail(signUpEmail) &&
        isValidPassword(signUpPassword) &&
        signUpPassword == signUpConfirmPassword &&
        isValidName(signUpStoreName) &&
        signUpAcceptedTerms
    }

    var passwordsMatch: Bool { signUpPassword == signUpConfirmPassword }
    var passwordLengthValid: Bool { isValidPassword(signUpPassword) }

    // MARK: - Actions

    func login() {
        guard !isLoggingIn else { return } // anti double-tap
        guard isLoginValid else {
            loginError = "Ingresa un correo válido y contraseña"
            return
        }
        isLoggingIn = true
        loginError = nil

        Task { @MainActor in
            do {
                let user = try await authRepository.login(
                    email: loginEmail.trimmingCharacters(in: .whitespaces),
                    password: loginPassword
                )
                self.currentUser = user
                withAnimation(.easeInOut(duration: 0.3)) { self.isAuthenticated = true }
                HapticManager.notification(.success)
            } catch {
                // No leak: mismo mensaje para user-not-found y wrong-password
                self.loginError = self.mapAuthError(error, fallback: "Credenciales incorrectas")
                HapticManager.notification(.error)
            }
            self.isLoggingIn = false
        }
    }

    func signUp() {
        guard !isSigningUp else { return } // anti double-tap
        guard isSignUpValid else { return }
        isSigningUp = true
        signUpError = nil

        Task { @MainActor in
            do {
                let user = try await authRepository.signUp(
                    email: signUpEmail.trimmingCharacters(in: .whitespaces),
                    password: signUpPassword,
                    name: signUpName.trimmingCharacters(in: .whitespacesAndNewlines),
                    storeName: signUpStoreName.trimmingCharacters(in: .whitespacesAndNewlines),
                    storeAddress: nil,
                    storePhone: nil
                )
                self.currentUser = user
                withAnimation(.easeInOut(duration: 0.3)) { self.isAuthenticated = true }
                HapticManager.notification(.success)
            } catch {
                // Mensaje genérico: no filtrar "email ya en uso"
                self.signUpError = self.mapAuthError(error, fallback: "No fue posible crear la cuenta. Intenta más tarde.")
                HapticManager.notification(.error)
            }
            self.isSigningUp = false
        }
    }

    func sendPasswordReset() {
        guard isValidEmail(forgotPasswordEmail) else {
            forgotPasswordError = "Ingresa un correo electrónico válido"
            return
        }
        // Rate limiting: 1 request por minuto
        if let last = lastForgotPasswordRequest,
           Date().timeIntervalSince(last) < forgotPasswordCooldown {
            let remaining = Int(forgotPasswordCooldown - Date().timeIntervalSince(last))
            forgotPasswordError = "Espera \(remaining) segundos antes de volver a intentar"
            return
        }

        lastForgotPasswordRequest = Date()

        Task { @MainActor in
            // Siempre mostramos éxito — no revelamos si el email existe
            _ = try? await authRepository.sendPasswordReset(
                email: forgotPasswordEmail.trimmingCharacters(in: .whitespaces)
            )
            self.forgotPasswordSent = true
            self.forgotPasswordError = nil
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.3)) { hasCompletedOnboarding = true }
    }

    // MARK: - OAuth Sign-In

    /// Sign in con Google vía Firebase OAuth.
    /// Abre una sesión web de autenticación usando ASWebAuthenticationSession.
    func signInWithGoogle() {
        signInWithOAuth(providerID: OAuthProviderID.google, providerName: "Google")
    }

    private func signInWithOAuth(providerID: String, providerName: String) {
        guard !isLoggingIn else { return }
        isLoggingIn = true
        loginError = nil

        Task { @MainActor in
            do {
                let user = try await authRepository.signInWithOAuth(providerID: providerID)
                self.currentUser = user
                withAnimation(.easeInOut(duration: 0.3)) { self.isAuthenticated = true }
                HapticManager.notification(.success)
            } catch let apiError as APIError {
                switch apiError {
                case .unknown(let message):
                    self.loginError = message
                case .offline, .networkError:
                    self.loginError = "Sin conexión. Revisa tu internet."
                default:
                    self.loginError = "No se pudo iniciar sesión con \(providerName)."
                }
                HapticManager.notification(.error)
            } catch {
                // Errores de Firebase SDK (user canceled, etc.)
                let nsErr = error as NSError
                // Código 17020 = network error; 17995/17200 = canceled
                if [17995, 17200].contains(nsErr.code) {
                    self.loginError = nil  // usuario canceló, no mostrar error
                } else {
                    self.loginError = "No se pudo iniciar sesión con \(providerName)."
                }
                HapticManager.notification(.error)
            }
            self.isLoggingIn = false
        }
    }

    func logout() {
        do {
            try authRepository.logout()
        } catch {
            // Continuar con logout local igualmente
        }
        persistence.clearUser()
        persistence.clearAllData()

        NotificationCenter.default.post(name: .userDidLogout, object: nil)

        withAnimation(.easeInOut(duration: 0.3)) {
            isAuthenticated = false
            currentUser = nil
            clearLoginFields()
        }
    }

    func clearLoginFields() { loginEmail = ""; loginPassword = ""; loginError = nil }

    func clearSignUpFields() {
        signUpName = ""; signUpEmail = ""; signUpPassword = ""
        signUpConfirmPassword = ""; signUpStoreName = ""
        signUpAcceptedTerms = false; signUpError = nil
    }

    // MARK: - Helpers

    /// Mapea errores a mensajes genéricos para no filtrar información
    private func mapAuthError(_ error: Error, fallback: String) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .offline, .networkError:
                return "Sin conexión. Revisa tu internet."
            default:
                break
            }
        }
        return fallback
    }

    private func handleTokenExpired() {
        Task { @MainActor in
            do {
                _ = try await authRepository.refreshToken()
            } catch {
                self.logout()
                self.loginError = "Sesión expirada. Inicia sesión de nuevo."
            }
        }
    }
}
