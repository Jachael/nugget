import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack {
                // Skip button at top right
                HStack {
                    Spacer()
                    if currentPage < 3 {
                        Button("Skip") {
                            hasSeenTutorial = true
                            dismiss()
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding()
                    }
                }

                TabView(selection: $currentPage) {
                    // Page 1: Welcome & Save Content
                    TutorialPage(
                        icon: "plus.app.fill",
                        iconColors: [Color.goldAccent, Color.goldAccent.opacity(0.6)],
                        title: "Save Everything",
                        description: "Add articles, links, and content from anywhere using the share button or paste URLs directly",
                        features: [
                            ("Share from Safari", "square.and.arrow.up"),
                            ("Paste URLs", "doc.on.clipboard"),
                            ("Organize by topic", "folder")
                        ],
                        currentPage: $currentPage
                    )
                    .tag(0)

                    // Page 2: Smart Processing
                    TutorialPage(
                        icon: "sparkles",
                        iconColors: [Color.goldAccent, Color.goldAccent.opacity(0.6)],
                        title: "AI-Powered Summaries",
                        description: "Get intelligent summaries and key insights from your saved content in seconds",
                        features: [
                            ("Key takeaways", "lightbulb"),
                            ("Smart grouping", "square.stack.3d.up"),
                            ("Instant insights", "bolt")
                        ],
                        currentPage: $currentPage
                    )
                    .tag(1)

                    // Page 3: Swipe to Learn
                    TutorialPage(
                        icon: "hand.draw",
                        iconColors: [Color.goldAccent, Color.goldAccent.opacity(0.6)],
                        title: "Swipe to Learn",
                        description: "Review your content in bite-sized cards. Swipe through summaries at your own pace",
                        features: [
                            ("Swipe cards", "rectangle.stack"),
                            ("Track progress", "chart.line.uptrend.xyaxis"),
                            ("Build streaks", "flame")
                        ],
                        currentPage: $currentPage
                    )
                    .tag(2)

                    // Page 4: Get Started
                    FinalTutorialPage {
                        hasSeenTutorial = true
                        dismiss()
                    }
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index == currentPage ? Color.goldAccent : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct TutorialPage: View {
    let icon: String
    let iconColors: [Color]
    let title: String
    let description: String
    let features: [(String, String)]
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title and description
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 32)

            // Feature list
            VStack(spacing: 16) {
                ForEach(features, id: \.0) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.1)
                            .font(.system(size: 16))
                            .foregroundColor(.goldAccent)
                            .frame(width: 24)

                        Text(feature.0)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassEffect(in: .rect(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Continue button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPage += 1
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14))
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .glassEffect(in: .capsule)
            }
            .padding(.bottom, 20)

            Spacer(minLength: 60)
        }
    }
}

struct FinalTutorialPage: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Final message
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Start saving content and building your personal knowledge library")
                    .font(.system(size: 16))
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
                HStack {
                    Text("Get Started")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14))
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.black)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)

            Spacer(minLength: 60)
        }
    }
}

#Preview {
    TutorialView()
}