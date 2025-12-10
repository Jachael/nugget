import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTierIndex = 1 // Start on Pro (middle)
    @State private var showPremiumOnboarding = false

    private var tiers: [TierInfo] {
        let proProduct = subscriptionService.products.first(where: { $0.id == "com.nugget.pro" })
        let ultimateProduct = subscriptionService.products.first(where: { $0.id == "com.nugget.ultimate" })

        return [
            TierInfo(
                tier: .free,
                name: "Free",
                price: "$0",
                period: "forever",
                features: [
                    "5 nuggets per day",
                    "3 swipe sessions",
                    "Learning streaks",
                    "5 friends max"
                ],
                product: nil,
                accentColor: .secondary
            ),
            TierInfo(
                tier: .plus,
                name: "Pro",
                price: proProduct?.displayPrice ?? "$4.99",
                period: "month",
                features: [
                    "50 nuggets per day",
                    "Unlimited swipes",
                    "Smart Processing",
                    "Reader Mode",
                    "25 friends"
                ],
                product: proProduct,
                accentColor: .blue
            ),
            TierInfo(
                tier: .pro,
                name: "Ultimate",
                price: ultimateProduct?.displayPrice ?? "$9.99",
                period: "month",
                features: [
                    "Unlimited nuggets",
                    "RSS feeds",
                    "Custom feeds",
                    "Offline mode",
                    "Unlimited friends"
                ],
                product: ultimateProduct,
                accentColor: .goldAccent
            )
        ]
    }

    private var selectedTier: TierInfo {
        tiers[selectedTierIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Compact tier selector
                tierSelector
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Scrollable content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Price display
                        priceCard
                            .padding(.top, 16)

                        // Features
                        featuresList
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                // Fixed bottom section with button
                bottomSection
            }
            .navigationTitle("Choose Your Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
            .overlay {
                if subscriptionService.isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                }
            }
        }
        .task {
            await subscriptionService.fetchProducts()
        }
        .alert("Error", isPresented: .constant(subscriptionService.purchaseError != nil)) {
            Button("OK") { }
        } message: {
            if let error = subscriptionService.purchaseError {
                Text(error)
            }
        }
        .fullScreenCover(isPresented: $showPremiumOnboarding, onDismiss: {
            dismiss()
        }) {
            PremiumOnboardingView()
                .environmentObject(authService)
        }
    }

    private var tierSelector: some View {
        HStack(spacing: 6) {
            ForEach(Array(tiers.enumerated()), id: \.offset) { index, tier in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTierIndex = index
                    }
                    HapticFeedback.light()
                } label: {
                    Text(tier.name)
                        .font(.system(size: 14, weight: selectedTierIndex == index ? .semibold : .medium))
                        .foregroundColor(selectedTierIndex == index ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTierIndex == index
                                ? Color.primary.opacity(0.1)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(3)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var priceCard: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(selectedTier.price)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.primary)

                if selectedTier.period != "forever" {
                    Text("/mo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            if selectedTier.tier != .free {
                Text("Cancel anytime")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassEffect(in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(selectedTier.accentColor.opacity(0.3), lineWidth: selectedTierIndex > 0 ? 2 : 0)
        )
    }

    private var featuresList: some View {
        VStack(spacing: 0) {
            ForEach(Array(selectedTier.features.enumerated()), id: \.offset) { index, feature in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(selectedTier.accentColor)

                    Text(feature)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)

                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                if index < selectedTier.features.count - 1 {
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private var bottomSection: some View {
        VStack(spacing: 12) {
            // Action button
            actionButton
                .padding(.horizontal, 20)

            // Footer links
            HStack(spacing: 12) {
                Button("Restore") {
                    Task { await restorePurchases() }
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)

                Text("·")
                    .foregroundColor(.secondary.opacity(0.5))

                Text("Auto-renews")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("·")
                    .foregroundColor(.secondary.opacity(0.5))

                Button("Terms") { }
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("·")
                    .foregroundColor(.secondary.opacity(0.5))

                Button("Privacy") { }
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 16)
        }
        .padding(.top, 12)
        .background(Color(UIColor.systemBackground))
    }

    @ViewBuilder
    private var actionButton: some View {
        let isCurrentTier = subscriptionService.currentTier == selectedTier.tier

        if selectedTier.tier == .free {
            if isCurrentTier {
                currentPlanButton
            } else {
                // User has a paid subscription, let them manage it
                manageSubscriptionButton
            }
        } else if selectedTier.product != nil {
            if isCurrentTier {
                currentPlanButton
            } else {
                Button {
                    if let product = selectedTier.product {
                        Task { await purchaseProduct(product) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Subscribe to \(selectedTier.name)")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(UIColor.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        } else {
            Text("Coming Soon")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var currentPlanButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
            Text("Current Plan")
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var manageSubscriptionButton: some View {
        Button {
            openSubscriptionManagement()
        } label: {
            HStack(spacing: 8) {
                Text("Manage Subscription")
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    private func purchaseProduct(_ product: Product) async {
        HapticFeedback.light()
        let success = await subscriptionService.purchase(product: product)
        if success {
            HapticFeedback.success()
            // Show premium onboarding flow
            showPremiumOnboarding = true
        } else {
            HapticFeedback.medium()
        }
    }

    private func restorePurchases() async {
        HapticFeedback.light()
        let success = await subscriptionService.restorePurchases()
        if success {
            HapticFeedback.success()
            // If they restored a premium subscription, show onboarding
            if subscriptionService.currentTier != .free {
                showPremiumOnboarding = true
            }
        } else {
            HapticFeedback.medium()
        }
    }
}

// MARK: - Supporting Types

struct TierInfo {
    let tier: SubscriptionTier
    let name: String
    let price: String
    let period: String
    let features: [String]
    let product: Product?
    let accentColor: Color
}

#Preview {
    SubscriptionView()
}
