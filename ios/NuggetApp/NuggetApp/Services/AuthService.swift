import Foundation
import AuthenticationServices

enum AuthError: Error {
    case invalidCredentials
    case networkError
    case unknown
}

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
                            streak: userProfile.streak,
                            firstName: userProfile.firstName
                        )
                    }
                } catch {
                    print("Failed to fetch user profile: \(error)")
                    // Still authenticated, just no streak available
                    await MainActor.run {
                        self.currentUser = User(
                            userId: userId,
                            accessToken: token,
                            streak: 0,
                            firstName: nil
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
        let firstName: String?
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
            streak: profile.streak,
            firstName: profile.firstName
        )
    }

    func signInWithApple(
        identityToken: String,
        authorizationCode: String,
        userIdentifier: String,
        email: String?,
        fullName: PersonNameComponents?
    ) async throws {
        struct AuthRequest: Codable {
            let identityToken: String
            let authorizationCode: String
            let userIdentifier: String
            let email: String?
            let firstName: String?
            let lastName: String?
        }

        let authRequest = AuthRequest(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            userIdentifier: userIdentifier,
            email: email,
            firstName: fullName?.givenName,
            lastName: fullName?.familyName
        )

        let authResponse = try await APIClient.shared.send(
            path: "/auth/apple",
            method: "POST",
            body: authRequest,
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
                streak: authResponse.streak,
                firstName: authResponse.firstName
            )
            self.isAuthenticated = true
        }
    }

    func signInWithMockToken() async throws {
        // For local testing - directly authenticate with backend
        struct MockAuthRequest: Codable {
            let mockUser: String
        }

        // Add special header for mock authentication in production
        var headers: [String: String] = [:]
        headers["X-Test-Auth"] = "nugget-test-2024"

        let authResponse = try await APIClient.shared.send(
            path: "/auth/mock",
            method: "POST",
            body: MockAuthRequest(mockUser: "test_user_\(UUID().uuidString.prefix(8))"),
            requiresAuth: false,
            responseType: AuthResponse.self,
            headers: headers
        )

        // Save credentials
        KeychainManager.shared.saveToken(authResponse.accessToken)
        KeychainManager.shared.saveUserId(authResponse.userId)

        // Update state
        await MainActor.run {
            self.currentUser = User(
                userId: authResponse.userId,
                accessToken: authResponse.accessToken,
                streak: authResponse.streak,
                firstName: authResponse.firstName
            )
            self.isAuthenticated = true
        }
    }

    func signOut() {
        KeychainManager.shared.clearAll()
        currentUser = nil
        isAuthenticated = false

        // Clear tutorial flag so new users see it again
        UserDefaults.standard.removeObject(forKey: "hasSeenTutorial")
    }

    func deleteAccount() async throws {
        // Call backend to delete account
        struct DeleteResponse: Codable {
            let message: String
        }

        _ = try await APIClient.shared.send(
            path: "/user",
            method: "DELETE",
            body: Optional<String>.none,
            requiresAuth: true,
            responseType: DeleteResponse.self
        )

        // Clear local data after successful deletion
        await MainActor.run {
            KeychainManager.shared.clearAll()
            currentUser = nil
            isAuthenticated = false
        }
    }
}
