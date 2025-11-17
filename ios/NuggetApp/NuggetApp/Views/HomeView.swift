import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isStartingSession = false
    @State private var session: Session?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)

                        Text("\(authService.currentUser?.streak ?? 0)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Day Streak")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)

                    Spacer()

                    VStack(spacing: 16) {
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(.white)
                                .cornerRadius(8)
                        }

                        Button {
                            startSession()
                        } label: {
                            HStack {
                                if isStartingSession {
                                    ProgressView()
                                } else {
                                    Image(systemName: "play.circle.fill")
                                    Text("Start Learning Session")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isStartingSession)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Welcome")
            .navigationDestination(item: $session) { session in
                SessionView(session: session)
            }
        }
    }

    private func startSession() {
        isStartingSession = true
        errorMessage = nil

        Task {
            do {
                let newSession = try await NuggetService.shared.startSession(size: 3)
                await MainActor.run {
                    session = newSession
                    isStartingSession = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to start session: \(error.localizedDescription)"
                    isStartingSession = false
                }
            }
        }
    }
}
