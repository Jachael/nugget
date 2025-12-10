import SwiftUI

// MARK: - Neutral Accent Color (monochromatic)
extension Color {
    static let goldAccent = Color.secondary // Changed from gold to neutral
    static let goldAccentLight = Color.secondary.opacity(0.3)
}

// MARK: - Spark Symbol
struct SparkSymbol {
    static let spark = "✦"
}

// MARK: - Liquid Glass Button Style with Ripple
struct LiquidGlassButtonStyle: ButtonStyle {
    @State private var isPressed = false
    @State private var rippleOpacity: Double = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .overlay(
                Circle()
                    .fill(Color.white.opacity(rippleOpacity))
                    .scaleEffect(configuration.isPressed ? 1.5 : 0.5)
                    .animation(.easeOut(duration: 0.25), value: configuration.isPressed)
            )
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    rippleOpacity = 0.2
                    withAnimation(.easeOut(duration: 0.25)) {
                        rippleOpacity = 0
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Floating Animation Modifier
struct FloatingAnimation: ViewModifier {
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 3)
                    .repeatForever(autoreverses: true)
                ) {
                    offset = -2
                }
            }
    }
}

extension View {
    func floatingAnimation() -> some View {
        modifier(FloatingAnimation())
    }
}

// MARK: - Glass Card with Parallax Tilt
struct ParallaxGlassCard<Content: View>: View {
    @State private var tilt: Double = 0
    @State private var specularOffset: CGFloat = -200
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .rotation3DEffect(
                .degrees(tilt),
                axis: (x: 1, y: 0, z: 0)
            )
            .overlay(
                // Specular highlight sweep
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.1),
                        Color.white.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 50)
                .offset(x: specularOffset)
                .opacity(specularOffset > -100 && specularOffset < 100 ? 1 : 0)
                .allowsHitTesting(false)
                .mask(
                    RoundedRectangle(cornerRadius: 16)
                )
            )
            .onAppear {
                // Specular highlight sweep animation
                withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
                    specularOffset = 200
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldValue, newValue in
                let velocity = newValue - (oldValue ?? 0)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    tilt = min(max(velocity * 0.02, -2), 2)
                }
            }
    }
}

// MARK: - Spark Pulse Animation
struct SparkPulse: View {
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 0

    var body: some View {
        Text(SparkSymbol.spark)
            .font(.system(size: 24))
            .foregroundColor(.goldAccent)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.2)) {
                    scale = 1.5
                    opacity = 1
                }
                withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                    scale = 2.0
                    opacity = 0
                }
            }
    }
}

// MARK: - Micro Bounce Scale
struct MicroBounceScale: ViewModifier {
    @State private var scale: CGFloat = 1
    let trigger: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.02
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
                    scale = 1.0
                }
            }
    }
}

// MARK: - Glass Shadow Drift
struct GlassShadowDrift: ViewModifier {
    @State private var shadowOffset: CGFloat = 0
    let scrollOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(
                color: Color.black.opacity(0.1),
                radius: 10,
                x: shadowOffset,
                y: 5
            )
            .onChange(of: scrollOffset) { _, offset in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    shadowOffset = min(max(offset * 0.01, -1), 1)
                }
            }
    }
}

// MARK: - Liquid Modal Transition
struct LiquidModalTransition: ViewModifier {
    let isPresented: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPresented ? 0.95 : 1.0)
            .blur(radius: isPresented ? 2 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
    }
}

// MARK: - Gold Underline
struct GoldUnderline: ViewModifier {
    func body(content: Content) -> some View {
        VStack(spacing: 4) {
            content
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.goldAccent.opacity(0),
                            Color.goldAccent,
                            Color.goldAccent.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
    }
}

// MARK: - Faint Gradient Card Header
struct FaintGradientHeader: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.primary.opacity(0.02),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 40)
        .allowsHitTesting(false)
    }
}

// MARK: - Haptic Feedback Helper
struct HapticFeedback {
    static func light() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    static func medium() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    static func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }

    static func selection() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
}

// MARK: - Spark Bullet Point
struct SparkBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(SparkSymbol.spark)
                .font(.caption)
                .foregroundColor(.goldAccent)
                .padding(.top, 2)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Category Dot (Unread indicator - white in dark mode, black in light mode)
struct GoldCategoryDot: View {
    var body: some View {
        Circle()
            .fill(Color.primary)
            .frame(width: 6, height: 6)
    }
}

// MARK: - Glass Button Styles

/// Prominent button style with black background in light mode, white background in dark mode
struct GlassProminentButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white : Color.black)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedback.light()
                }
            }
    }
}

/// Standard glass button style with black/white theme
struct GlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color.white : Color.black)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedback.light()
                }
            }
    }
}

/// Plain button style with haptic feedback for list items and cards
struct HapticPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedback.selection()
                }
            }
    }
}

extension View {
    func microBounceScale(trigger: Bool) -> some View {
        modifier(MicroBounceScale(trigger: trigger))
    }

    func glassShadowDrift(scrollOffset: CGFloat) -> some View {
        modifier(GlassShadowDrift(scrollOffset: scrollOffset))
    }

    func liquidModalTransition(isPresented: Bool) -> some View {
        modifier(LiquidModalTransition(isPresented: isPresented))
    }

    func goldUnderline() -> some View {
        modifier(GoldUnderline())
    }

    /// Adds haptic feedback when a toggle value changes
    func hapticToggle(_ value: Bool) -> some View {
        self.onChange(of: value) { _, _ in
            HapticFeedback.selection()
        }
    }
}

// MARK: - Premium Feature Gate

struct PremiumFeatureGate: View {
    let feature: String
    let description: String
    let icon: String
    let requiredTier: String

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.primary.opacity(0.6))

            // Text
            VStack(spacing: 12) {
                Text(feature)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Upgrade prompt
            VStack(spacing: 8) {
                Text("Requires \(requiredTier)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)

                NavigationLink {
                    SubscriptionView()
                } label: {
                    Text("Upgrade")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(UIColor.systemBackground))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.primary)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(feature)
        .navigationBarTitleDisplayMode(.inline)
    }
}