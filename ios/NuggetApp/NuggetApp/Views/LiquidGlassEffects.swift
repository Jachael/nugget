import SwiftUI

// MARK: - Gold Accent Color
extension Color {
    static let goldAccent = Color(red: 0.949, green: 0.773, blue: 0.447) // #F2C572
    static let goldAccentLight = Color(red: 0.949, green: 0.773, blue: 0.447).opacity(0.3)
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
                Color.goldAccent.opacity(0.05),
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

// MARK: - Gold Category Dot
struct GoldCategoryDot: View {
    var body: some View {
        Circle()
            .fill(Color.goldAccent)
            .frame(width: 6, height: 6)
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
}