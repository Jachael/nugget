import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)

                    Text("Nugget")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    Text("Daily micro-learning from saved content")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                VStack(spacing: 16) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(.white.opacity(0.9))
                            .cornerRadius(8)
                    }

                    Button {
                        signIn()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "person.circle.fill")
                                Text("Sign In (Test Mode)")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)

                    Text("Using mock authentication for testing")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }

    private func signIn() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.signInWithMockToken()
            } catch {
                await MainActor.run {
                    errorMessage = "Sign in failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}
