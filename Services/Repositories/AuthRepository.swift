import Foundation
import FirebaseAuth

protocol AuthRepositoryProtocol {
    func login(email: String, password: String) async throws -> User
    func signUp(email: String, password: String, name: String, storeName: String, storeAddress: String?, storePhone: String?) async throws -> User
    func sendPasswordReset(email: String) async throws
    func logout() throws
    func refreshToken() async throws -> String
    func getCurrentFirebaseUser() -> FirebaseAuth.User?
}

final class AuthRepository: AuthRepositoryProtocol {
    private let apiClient = APIClient.shared
    private let cache = PersistenceService.shared

    func login(email: String, password: String) async throws -> User {
        // 1. Authenticate with Firebase Auth
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        let firebaseUser = authResult.user

        // 2. Get ID token
        let idToken = try await firebaseUser.getIDToken()
        apiClient.setAuthToken(idToken)

        // 3. Call backend /auth/login with just uid — backend looks up storeId
        let authResponse: AuthResponseDTO = try await apiClient.request(
            .authLogin,
            method: .POST,
            body: ["uid": firebaseUser.uid]
        )

        // 4. Save storeId for future requests (X-Store-Id header)
        let storeIdString = authResponse.storeId
        APIConfig.storeId = storeIdString

        // 5. Convert to domain model and cache
        let user = User(
            id: UUID(deterministicFrom: authResponse.uid),
            fullName: authResponse.name,
            email: authResponse.email,
            phone: "",
            role: UserRole.fromBackend(authResponse.role),
            storeName: "",
            storeId: UUID(deterministicFrom: storeIdString),
            avatarURL: nil,
            joinDate: Date(),
            isActive: true
        )
        cache.saveUser(user)
        UserDefaults.standard.set(firebaseUser.uid, forKey: "firebaseUid")
        UserDefaults.standard.set(storeIdString, forKey: "currentStoreId")

        return user
    }

    func signUp(email: String, password: String, name: String, storeName: String, storeAddress: String?, storePhone: String?) async throws -> User {
        // 1. Call backend /auth/register (creates Firebase user + store)
        let request = AuthRegisterRequest(
            email: email,
            password: password,
            name: name,
            storeName: storeName,
            storeAddress: storeAddress,
            storePhone: storePhone
        )

        print("[AuthRepo] Calling /auth/register for \(email)")
        let authResponse: AuthResponseDTO
        do {
            authResponse = try await apiClient.request(
                .authRegister,
                method: .POST,
                body: request.toDict
            )
            print("[AuthRepo] Register success: uid=\(authResponse.uid), storeId=\(authResponse.storeId)")
        } catch {
            print("[AuthRepo] Register failed: \(error)")
            throw error
        }

        // 2. Sign in to Firebase Auth to get the token
        print("[AuthRepo] Signing in to Firebase Auth...")
        let authResult: AuthDataResult
        do {
            authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            print("[AuthRepo] Firebase signIn success")
        } catch {
            print("[AuthRepo] Firebase signIn failed: \(error)")
            throw error
        }
        let idToken = try await authResult.user.getIDToken()
        apiClient.setAuthToken(idToken)

        // 3. Save storeId
        let storeIdString = authResponse.storeId
        APIConfig.storeId = storeIdString

        // 4. Convert and cache
        var user = authResponse.toDomain()
        user = User(
            id: user.id,
            fullName: name,
            email: email,
            phone: "",
            role: .owner,
            storeName: storeName,
            storeId: UUID(deterministicFrom: storeIdString),
            avatarURL: nil,
            joinDate: Date(),
            isActive: true
        )
        cache.saveUser(user)

        UserDefaults.standard.set(authResult.user.uid, forKey: "firebaseUid")
        UserDefaults.standard.set(storeIdString, forKey: "currentStoreId")

        return user
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func logout() throws {
        try Auth.auth().signOut()
        apiClient.clearAuthToken()
        APIConfig.storeId = nil
        UserDefaults.standard.removeObject(forKey: "firebaseUid")
        UserDefaults.standard.removeObject(forKey: "currentStoreId")
        cache.clearUser()
    }

    func refreshToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw APIError.unauthorized
        }
        let token = try await user.getIDToken(forcingRefresh: true)
        apiClient.setAuthToken(token)
        return token
    }

    func getCurrentFirebaseUser() -> FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    /// Restore session from Firebase Auth state (called on app launch)
    func restoreSession() async -> User? {
        guard let firebaseUser = Auth.auth().currentUser else { return nil }

        do {
            let token = try await firebaseUser.getIDToken()
            apiClient.setAuthToken(token)

            // Restore storeId from UserDefaults
            if let storeId = UserDefaults.standard.string(forKey: "currentStoreId") {
                APIConfig.storeId = storeId
            }

            return cache.loadUser()
        } catch {
            return cache.loadUser() // Offline fallback
        }
    }
}
