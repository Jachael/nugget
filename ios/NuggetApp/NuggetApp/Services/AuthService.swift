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

            // Fetch user profile to get streak
            Task {
                do {
                    let userProfile = try await fetchUserProfile()
                    await MainActor.run {
                        self.currentUser = User(
                            userId: userId,
                            accessToken: token,
                            streak: userProfile.streak
                        )
                    }
                } catch {
                    print("Failed to fetch user profile: \(error)")
                    // Still authenticated, just no streak available
                    await MainActor.run {
                        self.currentUser = User(
                            userId: userId,
                            accessToken: token,
                            streak: 0
                        )
                    }
                }
            }
        }
    }

    struct UserProfileResponse: Codable {
        let userId: String
        let streak: Int
        let lastActiveDate: String
    }

    private func fetchUserProfile() async throws -> AuthResponse {
        let profile = try await APIClient.shared.send(
            path: "/me",
            method: "GET",
            body: Optional<String>.none,
            requiresAuth: true,
            responseType: UserProfileResponse.self
        )

        return AuthResponse(
            userId: profile.userId,
            accessToken: "", // Not needed for this use case
            streak: profile.streak
        )
    }

    func signInWithApple(idToken: String) async throws {
        struct AuthRequest: Codable {
            let idToken: String
        }

        let authResponse = try await APIClient.shared.send(
            path: CognitoConfig.authEndpoint,
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
