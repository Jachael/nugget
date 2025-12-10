import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var currentPage = 0

    private let totalPages = 5

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.systemGray6).opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button at top right
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button("Skip") {
                            hasSeenTutorial = true
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
                    // Page 1: Welcome
                    WelcomePage(currentPage: $currentPage)
                        .tag(0)

                    // Page 2: Save Content
                    SaveContentPage(currentPage: $currentPage)
                        .tag(1)

                    // Page 3: Smart Processing
                    SmartProcessingPage(currentPage: $currentPage)
                        .tag(2)

                    // Page 4: Friends & Sharing
                    FriendsSharingPage(currentPage: $currentPage)
                        .tag(3)

                    // Page 5: Get Started
                    GetStartedPage {
                        hasSeenTutorial = true
                        dismiss()
                    }
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Page 1: Welcome

struct WelcomePage: View {
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            VStack(spacing: 24) {
                HStack(spacing: 0) {
                    Text("Nugget")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.primary)
                    Text(SparkSymbol.spark)
                        .font(.system(size: 40))
                        .foregroundColor(.primary.opacity(0.6))
                }

                Text("Your personal knowledge library")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Feature highlights
            VStack(spacing: 16) {
                FeatureHighlight(
                    icon: "sparkles",
                    title: "AI-Powered Summaries",
                    subtitle: "Powered by Claude"
                )

                FeatureHighlight(
                    icon: "person.2",
                    title: "Share with Friends",
                    subtitle: "Learn together"
                )

                FeatureHighlight(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Track Your Progress",
                    subtitle: "Build learning streaks"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Continue button
            OnboardingContinueButton(currentPage: $currentPage)

            Spacer(minLength: 60)
        }
    }
}

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

// MARK: - Page 2: Save Content

struct SaveContentPage: View {
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 100, height: 100)

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 44))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 32)

            // Title and description
            VStack(spacing: 16) {
                Text("Save From Anywhere")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Use the Share Sheet in Safari or any app to save articles, videos, and more to Nugget")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 40)

            // Step by step
            VStack(spacing: 12) {
                StepRow(number: 1, text: "Find content in any app")
                StepRow(number: 2, text: "Tap the Share button")
                StepRow(number: 3, text: "Select Nugget")
            }
            .padding(.horizontal, 40)

            // Pro tip
            ProTipCard(text: "Drag Nugget to the front of your Share Sheet for quicker access")
                .padding(.horizontal, 32)
                .padding(.top, 24)

            Spacer()

            OnboardingContinueButton(currentPage: $currentPage)

            Spacer(minLength: 60)
        }
    }
}

struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 28, height: 28)

                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(UIColor.systemBackground))
            }

            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

struct ProTipCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundColor(.yellow)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Page 3: Smart Processing

struct SmartProcessingPage: View {
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 100, height: 100)

                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 32)

            // Title and description
            VStack(spacing: 16) {
                Text("AI-Powered Insights")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Nugget uses Claude AI to summarize your content and extract key takeaways")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 40)

            // Features
            VStack(spacing: 16) {
                SmartFeatureRow(icon: "text.quote", title: "Concise Summaries")
                SmartFeatureRow(icon: "lightbulb", title: "Key Takeaways")
                SmartFeatureRow(icon: "questionmark.bubble", title: "Thought-Provoking Questions")
                SmartFeatureRow(icon: "square.stack.3d.up", title: "Smart Grouping")
            }
            .padding(.horizontal, 40)

            Spacer()

            OnboardingContinueButton(currentPage: $currentPage)

            Spacer(minLength: 60)
        }
    }
}

struct SmartFeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}

// MARK: - Page 4: Friends & Sharing

struct FriendsSharingPage: View {
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.2")
                    .font(.system(size: 44))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 32)

            // Title and description
            VStack(spacing: 16) {
                Text("Learn Together")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Add friends and share interesting nuggets with them. Learn better together!")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 40)

            // Features
            VStack(spacing: 16) {
                SocialFeatureRow(icon: "qrcode", title: "Share your friend code")
                SocialFeatureRow(icon: "paperplane", title: "Send nuggets to friends")
                SocialFeatureRow(icon: "bubble.left.and.bubble.right", title: "Give feedback & vote on features")
            }
            .padding(.horizontal, 40)

            // Upgrade teaser
            VStack(spacing: 8) {
                Text("Unlock more with Pro & Ultimate")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("RSS feeds, unlimited nuggets, custom feeds, and more")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.goldAccent.opacity(0.15), Color.goldAccent.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.goldAccent.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 32)
            .padding(.top, 24)

            Spacer()

            OnboardingContinueButton(currentPage: $currentPage)

            Spacer(minLength: 60)
        }
    }
}

struct SocialFeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}

// MARK: - Page 5: Get Started

struct GetStartedPage: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Celebration icon
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 32)

            // Title and description
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Start saving content and building your personal knowledge library")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Get Started button
            Button {
                HapticFeedback.success()
                onComplete()
            } label: {
                HStack(spacing: 8) {
                    Text("Get Started")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(UIColor.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 80)
        }
    }
}

// MARK: - Shared Components

struct OnboardingContinueButton: View {
    @Binding var currentPage: Int

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentPage += 1
            }
            HapticFeedback.light()
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .glassEffect(in: .capsule)
        }
    }
}

#Preview {
    TutorialView()
}
