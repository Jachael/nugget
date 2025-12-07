import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.95, blue: 0.97),
                    Color(red: 0.98, green: 0.98, blue: 0.99)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text(SparkSymbol.spark)
                            .font(.system(size: 48))
                            .foregroundColor(.goldAccent)

                        Text("Upgrade Your Knowledge")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Choose the plan that works for you")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)

                    // Current Tier Badge
                    if subscriptionService.currentTier != .free {
                        currentTierBadge
                            .padding(.horizontal)
                    }

                    // Tier Comparison Cards
                    VStack(spacing: 16) {
                        // Free Tier
                        TierCard(
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
                            isCurrentTier: subscriptionService.currentTier == .free,
                            isPurchasable: false
                        )

                        // Plus Tier
                        if let plusProduct = subscriptionService.products.first(where: { $0.id == "com.nugget.plus" }) {
                            TierCard(
                                tier: .plus,
                                title: "Plus",
                                price: plusProduct.displayPrice,
                                period: "per month",
                                features: [
                                    "10 nuggets per day",
                                    "Auto-processing",
                                    "Smart grouping",
                                    "Priority support"
                                ],
                                isCurrentTier: subscriptionService.currentTier == .plus,
                                isPurchasable: true,
                                onPurchase: {
                                    selectedProduct = plusProduct
                                    Task {
                                        await purchaseProduct(plusProduct)
                                    }
                                }
                            )
                        }

                        // Pro Tier
                        if let proProduct = subscriptionService.products.first(where: { $0.id == "com.nugget.pro" }) {
                            TierCard(
                                tier: .pro,
                                title: "Pro",
                                price: proProduct.displayPrice,
                                period: "per month",
                                features: [
                                    "Unlimited nuggets",
                                    "RSS feed support",
                                    "Priority processing",
                                    "Advanced analytics",
                                    "Custom categories"
                                ],
                                isCurrentTier: subscriptionService.currentTier == .pro,
                                isPurchasable: true,
                                onPurchase: {
                                    selectedProduct = proProduct
                                    Task {
                                        await purchaseProduct(proProduct)
                                    }
                                },
                                isRecommended: true
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Restore Purchases Button
                    Button {
                        Task {
                            await restorePurchases()
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.goldAccent)
                    }
                    .padding(.top, 8)

                    // Terms and Privacy
                    VStack(spacing: 8) {
                        Text("Subscriptions auto-renew monthly")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 16) {
                            Button("Terms of Service") {
                                // Open terms
                            }
                            .font(.caption)
                            .foregroundColor(.goldAccent)

                            Button("Privacy Policy") {
                                // Open privacy
                            }
                            .font(.caption)
                            .foregroundColor(.goldAccent)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .overlay(alignment: .topTrailing) {
                // Close button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .padding()
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
                        .foregroundColor(.white)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
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

    private var currentTierBadge: some View {
        HStack(spacing: 8) {
            Text(SparkSymbol.spark)
                .font(.caption)
                .foregroundColor(.goldAccent)

            Text("Current Plan: \(subscriptionService.currentTier.rawValue.capitalized)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.goldAccent.opacity(0.3), lineWidth: 1)
                )
        )
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

// MARK: - Tier Card

struct TierCard: View {
    let tier: SubscriptionTier
    let title: String
    let price: String
    let period: String
    let features: [String]
    let isCurrentTier: Bool
    let isPurchasable: Bool
    var onPurchase: (() -> Void)?
    var isRecommended: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Recommended Badge
            if isRecommended {
                Text("RECOMMENDED")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.goldAccent)
                    )
                    .offset(y: 12)
                    .zIndex(1)
            }

            // Card Content
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isRecommended ? .goldAccent : .primary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(price)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)

                        Text("/ \(period)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, isRecommended ? 24 : 20)

                // Features
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(isRecommended ? .goldAccent : .green)

                            Text(feature)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Action Button
                if isPurchasable {
                    Button {
                        onPurchase?()
                    } label: {
                        Text(isCurrentTier ? "Current Plan" : "Subscribe")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isCurrentTier ? .secondary : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isCurrentTier ? Color.secondary.opacity(0.2) : Color.goldAccent)
                            )
                    }
                    .disabled(isCurrentTier)
                    .buttonStyle(LiquidGlassButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                } else if isCurrentTier {
                    Text("Current Plan")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.2))
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                } else {
                    Spacer()
                        .frame(height: 20)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isRecommended ? Color.goldAccent : Color.secondary.opacity(0.2),
                                lineWidth: isRecommended ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isRecommended ? Color.goldAccent.opacity(0.2) : Color.black.opacity(0.05),
                        radius: isRecommended ? 15 : 8,
                        x: 0,
                        y: isRecommended ? 5 : 2
                    )
            )
        }
    }
}

#Preview {
    SubscriptionView()
}
