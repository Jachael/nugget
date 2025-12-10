import SwiftUI

struct PremiumOnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authService: AuthService
    @State private var currentPage = 0
    @State private var showConfetti = false

    private var isUltimate: Bool {
        authService.currentUser?.subscriptionTier == "ultimate"
    }

    private var tierName: String {
        isUltimate ? "Ultimate" : "Pro"
    }

    private var totalPages: Int {
        isUltimate ? 4 : 3
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button at top right
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button("Skip") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                }
                .frame(height: 52)

                TabView(selection: $currentPage) {
                    PremiumWelcomePage(tierName: tierName, currentPage: $currentPage, showConfetti: $showConfetti)
                        .tag(0)

                    RSSFeedsOnboardingPage(currentPage: $currentPage)
                        .tag(1)

                    if isUltimate {
                        CustomDigestsOnboardingPage(currentPage: $currentPage)
                            .tag(2)

                        PremiumGetStartedPage(isUltimate: true) {
                            dismiss()
                        }
                        .tag(3)
                    } else {
                        PremiumGetStartedPage(isUltimate: false) {
                            dismiss()
                        }
                        .tag(2)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Minimal page indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.2))
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 40)
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiPieceView(
                        piece: piece,
                        isDark: colorScheme == .dark,
                        screenSize: geometry.size
                    )
                }
            }
            .onAppear {
                createConfetti(in: geometry.size)
            }
        }
    }

    private func createConfetti(in size: CGSize) {
        confettiPieces = (0..<120).map { index in
            // Random angle for burst direction (full 360 degrees)
            let angle = Double.random(in: 0...(2 * .pi))
            // Random distance from center
            let distance = Double.random(in: 100...400)

            // Calculate end position from center
            let endX = cos(angle) * distance
            let endY = sin(angle) * distance + 200 // Bias downward with gravity

            return ConfettiPiece(
                id: index,
                endX: endX,
                endY: endY,
                delay: Double.random(in: 0...0.5),
                duration: Double.random(in: 1.8...3.5),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: 180...720),
                opacity: Double.random(in: 0.6...1.0),
                width: CGFloat.random(in: 4...10),
                height: CGFloat.random(in: 12...24)
            )
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id: Int
    let endX: Double
    let endY: Double
    let delay: Double
    let duration: Double
    let rotation: Double
    let rotationSpeed: Double
    let opacity: Double
    let width: CGFloat
    let height: CGFloat
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let isDark: Bool
    let screenSize: CGSize

    @State private var animate = false

    var body: some View {
        Rectangle()
            .fill(isDark ? Color.white : Color.black)
            .frame(width: piece.width, height: piece.height)
            .opacity(animate ? 0 : piece.opacity)
            .rotationEffect(.degrees(animate ? piece.rotation + piece.rotationSpeed : piece.rotation))
            .position(
                x: screenSize.width / 2 + (animate ? piece.endX : 0),
                y: screenSize.height * 0.35 + (animate ? piece.endY : 0)
            )
            .onAppear {
                withAnimation(
                    .easeOut(duration: piece.duration)
                    .delay(piece.delay)
                ) {
                    animate = true
                }
            }
    }
}

// MARK: - Page 1: Premium Welcome

struct PremiumWelcomePage: View {
    let tierName: String
    @Binding var currentPage: Int
    @Binding var showConfetti: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Simple text-based welcome
            VStack(spacing: 20) {
                Text("Welcome to")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.secondary)

                Text(tierName)
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .foregroundColor(.primary)
                    .tracking(-1)

                Text("You've unlocked powerful features")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 60)

            // Unlocked features - minimal list
            VStack(spacing: 0) {
                UnlockedFeatureRow(title: "RSS Feeds", subtitle: "Subscribe to quality sources")
                Divider().padding(.horizontal)
                UnlockedFeatureRow(title: "Smart Processing", subtitle: "Automatic content summaries")
                Divider().padding(.horizontal)
                UnlockedFeatureRow(title: "Reader Mode", subtitle: "Distraction-free reading")
            }
            .padding(.horizontal, 32)

            Spacer()

            MinimalContinueButton(currentPage: $currentPage)

            Spacer(minLength: 60)
        }
    }
}

struct UnlockedFeatureRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Page 2: RSS Feeds

struct RSSFeedsOnboardingPage: View {
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            VStack(spacing: 12) {
                Text("RSS Feeds")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                Text("Subscribe to your favorite sources.\nNew articles delivered automatically.")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 48)

            // Categories - minimal
            VStack(spacing: 0) {
                FeedCategoryRow(category: "Technology", examples: "The Verge, Ars Technica")
                Divider().padding(.horizontal)
                FeedCategoryRow(category: "News", examples: "BBC, Reuters, NPR")
                Divider().padding(.horizontal)
                FeedCategoryRow(category: "Business", examples: "Bloomberg, Forbes")
                Divider().padding(.horizontal)
                FeedCategoryRow(category: "Science", examples: "Nature, Scientific American")
            }
            .padding(.horizontal, 32)

            // Tip
            Text("Profile → RSS Feeds")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.top, 32)

            Spacer()

            MinimalContinueButton(currentPage: $currentPage)

            Spacer(minLength: 60)
        }
    }
}

struct FeedCategoryRow: View {
    let category: String
    let examples: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Text(examples)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Page 3: Custom Digests (Ultimate Only)

struct CustomDigestsOnboardingPage: View {
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            VStack(spacing: 12) {
                Text("Custom Digests")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                Text("Combine multiple feeds into\npersonalized daily summaries.")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 48)

            // Example digests - minimal
            VStack(spacing: 0) {
                DigestExampleRow(title: "Morning Tech Brief", feedCount: 5)
                Divider().padding(.horizontal)
                DigestExampleRow(title: "Business Weekly", feedCount: 8)
                Divider().padding(.horizontal)
                DigestExampleRow(title: "Health & Science", feedCount: 4)
            }
            .padding(.horizontal, 32)

            // Offline mode mention
            VStack(spacing: 4) {
                Text("Plus: Offline Mode")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                Text("Download nuggets for reading anywhere")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)

            Spacer()

            MinimalContinueButton(currentPage: $currentPage)

            Spacer(minLength: 60)
        }
    }
}

struct DigestExampleRow: View {
    let title: String
    let feedCount: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Text("\(feedCount) feeds")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Final Page: Get Started

struct PremiumGetStartedPage: View {
    let isUltimate: Bool
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Simple completion message
            VStack(spacing: 16) {
                Text("You're ready")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                Text("Start exploring your new features")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 48)

            // Quick navigation hints
            VStack(spacing: 0) {
                QuickActionRow(title: "RSS Feeds", path: "Profile → RSS Feeds")
                Divider().padding(.horizontal)
                QuickActionRow(title: "Smart Processing", path: "Profile → Smart Processing")
                if isUltimate {
                    Divider().padding(.horizontal)
                    QuickActionRow(title: "Custom Digests", path: "Profile → Custom Digests")
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Final button
            Button {
                HapticFeedback.success()
                onComplete()
            } label: {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(UIColor.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 80)
        }
    }
}

struct QuickActionRow: View {
    let title: String
    let path: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Text(path)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Minimal Continue Button

struct MinimalContinueButton: View {
    @Binding var currentPage: Int

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
            }
            HapticFeedback.light()
        } label: {
            HStack(spacing: 6) {
                Text("Continue")
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .medium))
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    PremiumOnboardingView()
        .environmentObject(AuthService())
}
