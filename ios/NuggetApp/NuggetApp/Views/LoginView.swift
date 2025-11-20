import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var iconOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0

    var body: some View {
        ZStack {
            // Clean background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo and branding
                VStack(spacing: 8) {
                    Text("Nugget \(SparkSymbol.spark)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Learn Something New Every Day")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .opacity(iconOpacity)

                Spacer()

                // Authentication buttons
                VStack(spacing: 16) {
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.primary.opacity(0.8))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassEffect(.regular.tint(.orange), in: .capsule)
                        .padding(.horizontal, 40)
                    }

                    // Sign in with Apple button (following Apple's HIG)
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)  // Use black for light mode, white for dark mode
                    .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
                    .padding(.horizontal, 40)
                }
                .opacity(buttonsOpacity)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            animateEntrance()
        }
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            iconOpacity = 1
        }

        withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
            buttonsOpacity = 1
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    do {
                        // Extract user information
                        let userIdentifier = appleIDCredential.user
                        let fullName = appleIDCredential.fullName
                        let email = appleIDCredential.email

                        // Get identity token
                        guard let identityToken = appleIDCredential.identityToken,
                              let tokenString = String(data: identityToken, encoding: .utf8) else {
                            throw AuthError.invalidCredentials
                        }

                        // Get authorization code
                        guard let authorizationCode = appleIDCredential.authorizationCode,
                              let codeString = String(data: authorizationCode, encoding: .utf8) else {
                            throw AuthError.invalidCredentials
                        }

                        // Call backend to authenticate with Apple
                        try await authService.signInWithApple(
                            identityToken: tokenString,
                            authorizationCode: codeString,
                            userIdentifier: userIdentifier,
                            email: email,
                            fullName: fullName
                        )

                    } catch {
                        await MainActor.run {
                            errorMessage = "Sign in failed: \(error.localizedDescription)"
                            isLoading = false
                            HapticFeedback.error()
                        }
                    }
                }
            }

        case .failure(let error):
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            isLoading = false
            HapticFeedback.error()
        }
    }

    private func signInWithGoogle() {
        // TODO: Implement Google Sign In
        errorMessage = "Google Sign In coming soon"
        HapticFeedback.error()
    }

    private func signInWithMockToken() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.signInWithMockToken()
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Mock sign in failed: \(error.localizedDescription)"
                    isLoading = false
                    HapticFeedback.error()
                }
            }
        }
    }
}

// Custom haptic feedback for errors
extension HapticFeedback {
    static func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}