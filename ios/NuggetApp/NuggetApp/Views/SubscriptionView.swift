import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var currentIndex = 1 // Start on Pro (middle card)
    @State private var dragOffset: CGFloat = 0

    private let cardWidth: CGFloat = UIScreen.main.bounds.width - 64
    private let cardSpacing: CGFloat = 12

    private var tiers: [TierData] {
        let proProduct = subscriptionService.products.first(where: { $0.id == "com.nugget.pro" })
        let ultimateProduct = subscriptionService.products.first(where: { $0.id == "com.nugget.ultimate" })

        return [
            TierData(
                tier: .free,
                title: "Free",
                price: "$0",
                period: "forever",
                features: [
                    "3 nuggets per day",
                    "Basic processing",
                    "Manual nugget creation",
                    "Daily learning streaks"
                ],
                product: nil,
                isRecommended: false
            ),
            TierData(
                tier: .plus,
                title: "Pro",
                price: proProduct?.displayPrice ?? "$4.99",
                period: "per month",
                features: [
                    "10 nuggets per day",
                    "Auto-processing",
                    "Smart grouping",
                    "Push notifications",
                    "Priority support"
                ],
                product: proProduct,
                isRecommended: false
            ),
            TierData(
                tier: .pro,
                title: "Ultimate",
                price: ultimateProduct?.displayPrice ?? "$9.99",
                period: "per month",
                features: [
                    "Unlimited nuggets",
                    "RSS feed support",
                    "Priority processing",
                    "Advanced analytics",
                    "Custom categories",
                    "Early access to features"
                ],
                product: ultimateProduct,
                isRecommended: true
            )
        ]
    }

    var body: some View {
        ZStack {
            // Clear background for system blur
            Color.clear
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, 16)

                Spacer()

                // Swipeable Cards
                GeometryReader { geometry in
                    let totalOffset = -CGFloat(currentIndex) * (cardWidth + cardSpacing) + (geometry.size.width - cardWidth) / 2

                    HStack(spacing: cardSpacing) {
                        ForEach(Array(tiers.enumerated()), id: \.offset) { index, tier in
                            SubscriptionTierCard(
                                tier: tier,
                                isCurrentTier: isCurrentTier(tier.tier),
                                onPurchase: {
                                    if let product = tier.product {
                                        selectedProduct = product
                                        Task {
                                            await purchaseProduct(product)
                                        }
                                    }
                                }
                            )
                            .frame(width: cardWidth)
                            .scaleEffect(index == currentIndex ? 1.0 : 0.92)
                            .opacity(index == currentIndex ? 1.0 : 0.6)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentIndex)
                        }
                    }
                    .offset(x: totalOffset + dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 50
                                var newIndex = currentIndex

                                if value.translation.width < -threshold && currentIndex < tiers.count - 1 {
                                    newIndex = currentIndex + 1
                                } else if value.translation.width > threshold && currentIndex > 0 {
                                    newIndex = currentIndex - 1
                                }

                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    currentIndex = newIndex
                                    dragOffset = 0
                                }

                                HapticFeedback.light()
                            }
                    )
                }
                .frame(height: 480)

                // Page Indicators
                pageIndicators
                    .padding(.top, 20)

                Spacer()

                // Footer
                footerView
                    .padding(.bottom, 32)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .glassEffect(in: .circle)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                Spacer()
            }

            // Loading Overlay
            if subscriptionService.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.goldAccent)

                    Text("Processing...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(32)
                .glassEffect(in: .rect(cornerRadius: 20))
            }
        }
        .task {
            await subscriptionService.fetchProducts()
        }
        .alert("Error", isPresented: .constant(subscriptionService.purchaseError != nil)) {
            Button("OK") {
                // Clear error
            }
        } message: {
            if let error = subscriptionService.purchaseError {
                Text(error)
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            Text(SparkSymbol.spark)
                .font(.system(size: 44))

            Text("Upgrade Your Learning")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.primary)

            Text("Swipe to explore plans")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<tiers.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.goldAccent : Color.secondary.opacity(0.3))
                    .frame(width: index == currentIndex ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentIndex)
            }
        }
    }

    private var footerView: some View {
        VStack(spacing: 16) {
            // Restore Purchases Button
            Button {
                Task {
                    await restorePurchases()
                }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.goldAccent)
            }

            // Terms and Privacy
            HStack(spacing: 20) {
                Button("Terms") {
                    // Open terms
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary.opacity(0.5))

                Text("Auto-renews monthly")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary.opacity(0.5))

                Button("Privacy") {
                    // Open privacy
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }

    private func isCurrentTier(_ tier: SubscriptionTier) -> Bool {
        subscriptionService.currentTier == tier
    }

    private func purchaseProduct(_ product: Product) async {
        HapticFeedback.light()
        let success = await subscriptionService.purchase(product: product)

        if success {
            HapticFeedback.success()
            dismiss()
        } else {
            HapticFeedback.medium()
        }
    }

    private func restorePurchases() async {
        HapticFeedback.light()
        let success = await subscriptionService.restorePurchases()

        if success {
            HapticFeedback.success()
        } else {
            HapticFeedback.medium()
        }
    }
}

// MARK: - Tier Data Model

struct TierData {
    let tier: SubscriptionTier
    let title: String
    let price: String
    let period: String
    let features: [String]
    let product: Product?
    let isRecommended: Bool
}

// MARK: - Subscription Tier Card

struct SubscriptionTierCard: View {
    let tier: TierData
    let isCurrentTier: Bool
    let onPurchase: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Recommended Badge
            if tier.isRecommended {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("BEST VALUE")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.goldAccent, Color.goldAccent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .offset(y: 14)
                .zIndex(1)
            }

            // Card Content
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(tier.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(tier.isRecommended ? .goldAccent : .primary)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(tier.price)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.primary)

                        Text("/ \(tier.period)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, tier.isRecommended ? 28 : 24)

                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 24)

                // Features
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(tier.features, id: \.self) { feature in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle()
                                        .fill(Color.secondary.opacity(0.15))
                                )

                            Text(feature)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

                Spacer()

                // Action Button
                actionButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .glassEffect(in: .rect(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        tier.isRecommended ? Color.goldAccent.opacity(0.5) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if tier.tier == .free {
            if isCurrentTier {
                currentPlanButton
            } else {
                // Free tier, not current - no button needed
                EmptyView()
            }
        } else if tier.product != nil {
            if isCurrentTier {
                currentPlanButton
            } else {
                subscribeButton
            }
        } else {
            comingSoonButton
        }
    }

    private var subscribeButton: some View {
        Button {
            onPurchase()
        } label: {
            HStack(spacing: 8) {
                Text("Subscribe")
                    .font(.system(size: 17, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.goldAccent, Color.goldAccent.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .shadow(color: Color.goldAccent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var currentPlanButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
            Text("Current Plan")
                .font(.system(size: 17, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }

    private var comingSoonButton: some View {
        Text("Coming Soon")
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    SubscriptionView()
}
