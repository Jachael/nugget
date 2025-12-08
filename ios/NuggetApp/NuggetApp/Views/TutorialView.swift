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
                    ShareSheetTutorialPage(currentPage: $currentPage)
                        .tag(0)

                    // Page 2: Smart Processing
                    TutorialPage(
                        icon: "sparkles",
                        iconColors: [Color.primary, Color.primary.opacity(0.6)],
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
                        iconColors: [Color.primary, Color.primary.opacity(0.6)],
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
                            .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct ShareSheetTutorialPage: View {
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title and description
            VStack(spacing: 16) {
                Text("Save Content with Share Sheet")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("When you find content in Safari or any app, use the Share Sheet to save it to Nugget")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 32)

            // Visual step-by-step guide
            VStack(spacing: 16) {
                // Step 1
                ShareSheetStep(
                    number: 1,
                    icon: "safari",
                    title: "Find content in any app",
                    description: "Safari, News, Twitter, etc."
                )

                // Step 2
                ShareSheetStep(
                    number: 2,
                    icon: "square.and.arrow.up",
                    title: "Tap the Share button",
                    description: "Usually at the top or bottom"
                )

                // Step 3
                ShareSheetStep(
                    number: 3,
                    icon: "checkmark.circle.fill",
                    title: "Select Nugget",
                    description: "Content saved instantly"
                )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)

            // Pro tip section
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                    Text("Pro Tip")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }

                Text("You can drag Nugget to the front of your Share Sheet for quicker access. Just scroll to the end, tap Edit Actions, and reorder apps.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
            )
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

struct ShareSheetStep: View {
    let number: Int
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            // Step number circle
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 40, height: 40)

                Text("\(number)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
            }

            // Icon
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.primary)
                .frame(width: 32)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 12))
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
                            .foregroundColor(.primary)
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