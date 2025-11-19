import SwiftUI

struct SplashView: View {
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var typedText = ""
    @State private var textScale: CGFloat = 1.0
    @State private var fontSize: CGFloat = 48
    @State private var textOpacity: Double = 1.0
    @State private var backgroundColor: Color = .white
    @State private var overlayOpacity: Double = 0.0
    @State private var isZooming = false
    @State private var hasStarted = false

    private let fullText = "Nugget"

    private var isDarkMode: Bool {
        if colorScheme == "dark" {
            return true
        } else if colorScheme == "light" {
            return false
        } else {
            // System preference
            return systemColorScheme == .dark
        }
    }

    private var textColor: Color {
        // For light mode preference: white text, for dark mode: black text
        isDarkMode ? .black : .white
    }

    private var backgroundStartColor: Color {
        // For light mode preference: black background, for dark mode: white background
        isDarkMode ? .white : .black
    }

    var body: some View {
        ZStack {
            // Background that will change based on theme
            backgroundColor
                .ignoresSafeArea()

            // Center the text without GeometryReader to avoid layout issues
            Text(typedText)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
                .scaleEffect(textScale, anchor: .center) // Explicitly set anchor point
                .opacity(textOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(nil, value: typedText) // Prevent animation on typing
                .drawingGroup() // Renders at high quality before scaling

            // Overlay that fades in to create seamless transition
            // Should match the text color (what we're zooming into)
            textColor
                .ignoresSafeArea()
                .opacity(overlayOpacity)
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            backgroundColor = backgroundStartColor
            startTypingAnimation()
        }
    }

    private func startTypingAnimation() {
        // Type out "Nugget" letter by letter with smoother timing
        for (index, letter) in fullText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                typedText.append(letter)
            }
        }

        // After typing completes, start zoom animation
        let typingDuration = Double(fullText.count) * 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration + 0.4) {
            startZoomAnimation()
        }
    }

    private func startZoomAnimation() {
        guard !isZooming else { return }
        isZooming = true

        // Smooth zoom into center with high quality text
        withAnimation(.easeInOut(duration: 0.8)) {
            fontSize = 180  // Larger font for better resolution
            textScale = 10.0  // Scale to fill screen completely
        }

        // Start fading overlay earlier to blend smoothly
        withAnimation(.easeIn(duration: 0.6).delay(0.5)) {
            overlayOpacity = 1.0  // Fade in the final color
        }

        // Background stays dark/light - we don't need to transition it
        // The overlay will create the final effect
    }
}

#Preview {
    SplashView()
}