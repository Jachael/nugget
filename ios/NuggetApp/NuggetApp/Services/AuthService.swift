import Foundation
import AuthenticationServices

enum AuthError: Error {
    case invalidCredentials
    case networkError
    case tokenExpired
    case unknown
}

// JWT Token Helper for decoding and validating tokens
struct JWTHelper {
    static func decode(_ token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }

        // Decode the payload (second segment)
        var base64 = segments[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json
    }

    static func isTokenExpired(_ token: String, bufferSeconds: TimeInterval = 60) -> Bool {
        guard let payload = decode(token),
              let exp = payload["exp"] as? TimeInterval else {
            // If we can't decode or find exp, treat as expired for safety
            return true
        }

        let expirationDate = Date(timeIntervalSince1970: exp)
        let now = Date()

        // Add a buffer to expire tokens slightly early to avoid edge cases
        return expirationDate.addingTimeInterval(-bufferSeconds) <= now
    }
}

final class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?

    init() {
        checkAuthStatus()

        // Listen for unauthorized errors from API (401 responses)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnauthorized),
            name: .apiUnauthorized,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleUnauthorized() {
        Task { @MainActor in
            print("Received 401 unauthorized - signing out")
            self.signOut()
        }
    }

    func checkAuthStatus() {
        if let token = KeychainManager.shared.getToken(),
           let userId = KeychainManager.shared.getUserId() {

            // Check if token is expired before considering user authenticated
            if JWTHelper.isTokenExpired(token) {
                print("Token is expired, signing out")
                signOut()
                return
            }

            // Token exists and is valid, user is authenticated
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
                    // If we get unauthorized error, sign out
                    if let apiError = error as? APIError, case .unauthorized = apiError {
                        await MainActor.run {
                            self.signOut()
                        }
                    } else {
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
