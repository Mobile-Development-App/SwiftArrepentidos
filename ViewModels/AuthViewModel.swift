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

    private let authRepository = AuthRepository()
    private let persistence = PersistenceService.shared
    private var tokenExpirationObserver: Any?

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        // Try to restore session from Firebase Auth + cache
        if let savedUser = persistence.loadUser() {
            currentUser = savedUser
            isAuthenticated = true

            // Restore API token in background
            Task { [weak self] in
                if let user = await self?.authRepository.restoreSession() {
                    self?.currentUser = user
                }
            }
        }

        // Listen for token expiration from APIClient
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

    var isLoginValid: Bool { !loginEmail.isEmpty && !loginPassword.isEmpty && loginEmail.contains("@") }

    var isSignUpValid: Bool {
        !signUpName.isEmpty && !signUpEmail.isEmpty && signUpEmail.contains("@") &&
        signUpPassword.count >= 8 && signUpPassword == signUpConfirmPassword &&
        !signUpStoreName.isEmpty && signUpAcceptedTerms
    }

    var passwordsMatch: Bool { signUpPassword == signUpConfirmPassword }
    var passwordLengthValid: Bool { signUpPassword.count >= 8 }

    func login() {
        isLoggingIn = true
        loginError = nil

        Task { @MainActor in
            do {
                let user = try await authRepository.login(email: loginEmail, password: loginPassword)
                self.currentUser = user
                withAnimation(.easeInOut(duration: 0.3)) { self.isAuthenticated = true }
                HapticManager.notification(.success)
            } catch let error as APIError {
                self.loginError = error.localizedDescription
                HapticManager.notification(.error)
            } catch {
                self.loginError = "Credenciales invalidas. Intenta de nuevo."
                HapticManager.notification(.error)
            }
            self.isLoggingIn = false
        }
    }

    func signUp() {
        guard isSignUpValid else { return }
        isSigningUp = true
        signUpError = nil

        Task { @MainActor in
            do {
                let user = try await authRepository.signUp(
                    email: signUpEmail,
                    password: signUpPassword,
                    name: signUpName,
                    storeName: signUpStoreName,
                    storeAddress: nil,
                    storePhone: nil
                )
                self.currentUser = user
                withAnimation(.easeInOut(duration: 0.3)) { self.isAuthenticated = true }
                HapticManager.notification(.success)
            } catch let error as APIError {
                self.signUpError = error.localizedDescription
                HapticManager.notification(.error)
            } catch {
                print("[AuthVM] SignUp error: \(error)")
                self.signUpError = "Error al crear la cuenta: \(error.localizedDescription)"
                HapticManager.notification(.error)
            }
            self.isSigningUp = false
        }
    }

    func sendPasswordReset() {
        guard !forgotPasswordEmail.isEmpty, forgotPasswordEmail.contains("@") else {
            forgotPasswordError = "Ingresa un correo electronico valido"
            return
        }

        Task { @MainActor in
            do {
                try await authRepository.sendPasswordReset(email: forgotPasswordEmail)
                self.forgotPasswordSent = true
                self.forgotPasswordError = nil
            } catch {
                self.forgotPasswordError = "Error al enviar el correo. Intenta de nuevo."
            }
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.3)) { hasCompletedOnboarding = true }
    }

    func logout() {
        do {
            try authRepository.logout()
        } catch {
            // Still proceed with local logout
        }
        persistence.clearUser()
        persistence.clearAllData()

        // Notify other ViewModels to clear their in-memory data
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

    private func handleTokenExpired() {
        Task { @MainActor in
            do {
                _ = try await authRepository.refreshToken()
            } catch {
                self.logout()
                self.loginError = "Sesion expirada. Inicia sesion de nuevo."
            }
        }
    }
}
