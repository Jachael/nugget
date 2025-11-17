import Foundation
import AuthenticationServices

final class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?

    init() {
        checkAuthStatus()
    }

    func checkAuthStatus() {
        if let token = KeychainManager.shared.getToken(),
           let userId = KeychainManager.shared.getUserId() {
            // Token exists, user is authenticated
            isAuthenticated = true
            // Note: We don't store streak in keychain, it's fetched fresh on auth
        }
    }

    func signInWithApple(idToken: String) async throws {
        struct AuthRequest: Codable {
            let idToken: String
        }

        let authResponse = try await APIClient.shared.send(
            path: "/auth/apple",
            method: "POST",
            body: AuthRequest(idToken: idToken),
            requiresAuth: false,
            responseType: AuthResponse.self
        )

        // Save credentials
        KeychainManager.shared.saveToken(authResponse.accessToken)
        KeychainManager.shared.saveUserId(authResponse.userId)

        // Update state
        await MainActor.run {
            self.currentUser = User(
                userId: authResponse.userId,
                accessToken: authResponse.accessToken,
                streak: authResponse.streak
            )
            self.isAuthenticated = true
        }
    }

    func signInWithMockToken() async throws {
        // For local testing without Apple Sign In
        let mockToken = "mock_test_user_\(UUID().uuidString)"
        try await signInWithApple(idToken: mockToken)
    }

    func signOut() {
        KeychainManager.shared.clearAll()
        currentUser = nil
        isAuthenticated = false
    }
}
