import SwiftUI

struct BetaWelcomeView: View {
    let userName: String
    let onContinue: () -> Void

    @State private var showContent = false
    @State private var showButton = false
    @State private var showConfetti = false

    private var firstName: String {
        userName.components(separatedBy: " ").first ?? userName
    }

    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Main content
                VStack(spacing: 32) {
                    // Icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 56))
                        .foregroundStyle(.primary)
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.5)

                    // Text content
                    VStack(spacing: 16) {
                        Text("Welcome, \(firstName)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Thank you for testing Nugget")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                    // Ultimate badge
                    VStack(spacing: 12) {
                        Text("ULTIMATE")
                            .font(.system(size: 14, weight: .bold))
                            .kerning(1.5)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                            )

                        Text("Your subscription is on us\nduring the beta period")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                }
                .padding(.horizontal, 40)

                Spacer()

                // Continue button
                Button {
                    HapticFeedback.medium()
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.primary)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 30)
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                showButton = true
            }
            // Trigger confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
        }
    }
}

// MARK: - TestFlight Detection

struct TestFlightHelper {
    /// Check if the app is running as a TestFlight build
    static var isTestFlight: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return receiptURL.path.contains("sandboxReceipt")
    }

    /// Key for tracking if user has seen the beta welcome
    private static let hasSeenBetaWelcomeKey = "hasSeenBetaWelcome"

    /// Check if user has already seen the beta welcome
    static var hasSeenBetaWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenBetaWelcomeKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenBetaWelcomeKey) }
    }

    /// Should show beta welcome (TestFlight + not seen yet)
    static var shouldShowBetaWelcome: Bool {
        isTestFlight && !hasSeenBetaWelcome
    }

    /// Mark beta welcome as seen
    static func markBetaWelcomeSeen() {
        hasSeenBetaWelcome = true
    }
}

#Preview {
    BetaWelcomeView(userName: "Jason") {
        print("Continue tapped")
    }
}
