import SwiftUI

struct SplashView: View {
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var iconScale: CGFloat = 0
    @State private var iconOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var hasStarted = false

    private var isDarkMode: Bool {
        if colorScheme == "dark" {
            return true
        } else if colorScheme == "light" {
            return false
        } else {
            return systemColorScheme == .dark
        }
    }

    var body: some View {
        ZStack {
            // Clean background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Centered logo animation
                ZStack {
                    // Subtle expanding ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.goldAccent.opacity(0.2),
                                    Color.goldAccent.opacity(0)
                                ],
                                startPoint: .center,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Icon with liquid glass effect
                    ZStack {
                        // Soft glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.goldAccent.opacity(0.08),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 160, height: 160)
                            .blur(radius: 15)
                            .opacity(iconOpacity)

                        // Main icon
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.goldAccent,
                                        Color.goldAccent.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(28)
                            .glassEffect(in: .circle)
                            .shadow(color: Color.goldAccent.opacity(0.15), radius: 10, x: 0, y: 4)
                    }
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                }

                // App name appears after icon
                VStack(spacing: 6) {
                    Text("Nugget")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Learn Something New")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                .opacity(textOpacity)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            startAnimationSequence()
        }
    }

    private func startAnimationSequence() {
        // Phase 1: Icon scales up with spring animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            iconScale = 1
            iconOpacity = 1
        }

        // Phase 2: Ring expands subtly
        withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
            ringScale = 1.4
            ringOpacity = 1
        }

        // Phase 3: Text fades in
        withAnimation(.easeIn(duration: 0.5).delay(0.5)) {
            textOpacity = 1
        }

        // Phase 4: Ring fades out
        withAnimation(.easeOut(duration: 0.8).delay(1.0)) {
            ringOpacity = 0
        }
    }
}

#Preview {
    SplashView()
}