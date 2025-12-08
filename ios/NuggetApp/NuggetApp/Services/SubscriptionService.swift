import Foundation
import StoreKit

enum SubscriptionTier: String, Codable {
    case free = "free"
    case plus = "pro"        // "Pro" tier in UI
    case pro = "ultimate"    // "Ultimate" tier in UI

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .plus: return "Pro"
        case .pro: return "Ultimate"
        }
    }

    var dailyNuggetLimit: Int {
        switch self {
        case .free: return 3
        case .plus: return 10
        case .pro: return Int.max
        }
    }

    var hasAutoProcess: Bool {
        switch self {
        case .free: return false
        case .plus, .pro: return true
        }
    }

    var hasRSSSupport: Bool {
        switch self {
        case .free, .plus: return false
        case .pro: return true
        }
    }

    var hasPriorityProcessing: Bool {
        switch self {
        case .free, .plus: return false
        case .pro: return true
        }
    }
}

final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    // Product IDs
    private let proProductId = "com.nugget.pro"           // "Pro" tier
    private let ultimateProductId = "com.nugget.ultimate" // "Ultimate" tier

    @Published private(set) var products: [Product] = []
    @Published private(set) var currentTier: SubscriptionTier = .free
    @Published private(set) var isLoading = false
    @Published private(set) var purchaseError: String?

    private var updateListenerTask: Task<Void, Error>?
    private let userDefaultsKey = "subscriptionTier"

    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        // Load cached subscription tier
        if let savedTier = UserDefaults.standard.string(forKey: userDefaultsKey),
           let tier = SubscriptionTier(rawValue: savedTier) {
            currentTier = tier
        }

        // Check current subscription status on init
        Task {
            await checkSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Fetch Products

    func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIds: Set<String> = [proProductId, ultimateProductId]
            print("🔍 Requesting products: \(productIds)")

            let loadedProducts = try await Product.products(for: productIds)

            await MainActor.run {
                self.products = loadedProducts.sorted { $0.price < $1.price }
            }

            print("✅ Fetched \(loadedProducts.count) products:")
            for product in loadedProducts {
                print("   - \(product.id): \(product.displayName) @ \(product.displayPrice)")
            }

            if loadedProducts.isEmpty {
                print("⚠️ No products returned. Check:")
                print("   1. Product IDs match exactly in App Store Connect")
                print("   2. Paid Applications Agreement is signed")
                print("   3. Products have prices and localizations set")
                print("   4. Bundle ID matches your app")
            }
        } catch {
            print("❌ Failed to fetch products: \(error)")
            await MainActor.run {
                self.purchaseError = "Failed to load subscription options"
            }
        }
    }

    // MARK: - Purchase

    func purchase(product: Product) async -> Bool {
        await MainActor.run {
            isLoading = true
            purchaseError = nil
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)

                // Update subscription status
                await updateSubscriptionStatus(from: transaction)

                // Finish the transaction
                await transaction.finish()

                // Sync with backend
                await syncSubscriptionWithBackend(transaction: transaction)

                print("✅ Purchase successful: \(product.id)")
                return true

            case .userCancelled:
                print("ℹ️ User cancelled purchase")
                return false

            case .pending:
                print("⏳ Purchase pending")
                await MainActor.run {
                    self.purchaseError = "Purchase is pending approval"
                }
                return false

            @unknown default:
                print("❌ Unknown purchase result")
                return false
            }
        } catch {
            print("❌ Purchase failed: \(error)")
            await MainActor.run {
                self.purchaseError = "Purchase failed: \(error.localizedDescription)"
            }
            return false
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async -> Bool {
        await MainActor.run {
            isLoading = true
            purchaseError = nil
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            print("✅ Purchases restored")
            return true
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            await MainActor.run {
                self.purchaseError = "Failed to restore purchases"
            }
            return false
        }
    }

    // MARK: - Check Subscription Status

    func checkSubscriptionStatus() async {
        var highestTier: SubscriptionTier = .free
        var latestTransaction: Transaction?

        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Determine tier from product ID
                let tier = tierFromProductId(transaction.productID)

                // Keep the highest tier
                if tier == .pro || (tier == .plus && highestTier == .free) {
                    highestTier = tier
                    latestTransaction = transaction
                }
            } catch {
                print("❌ Failed to verify transaction: \(error)")
            }
        }

        await MainActor.run {
            self.currentTier = highestTier
            self.saveTierToUserDefaults(highestTier)
        }

        // Sync with backend if we have an active subscription
        if let transaction = latestTransaction {
            await syncSubscriptionWithBackend(transaction: transaction)
        }

        print("✅ Current subscription tier: \(highestTier.rawValue)")
    }

    // MARK: - Transaction Updates Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Update subscription status
                    await self.updateSubscriptionStatus(from: transaction)

                    // Sync with backend
                    await self.syncSubscriptionWithBackend(transaction: transaction)

                    // Finish the transaction
                    await transaction.finish()
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func updateSubscriptionStatus(from transaction: Transaction) async {
        let tier = tierFromProductId(transaction.productID)

        await MainActor.run {
            self.currentTier = tier
            self.saveTierToUserDefaults(tier)
        }
    }

    private func tierFromProductId(_ productId: String) -> SubscriptionTier {
        switch productId {
        case proProductId:
            return .plus      // "Pro" tier
        case ultimateProductId:
            return .pro       // "Ultimate" tier
        default:
            return .free
        }
    }

    private func saveTierToUserDefaults(_ tier: SubscriptionTier) {
        UserDefaults.standard.set(tier.rawValue, forKey: userDefaultsKey)
    }

    // MARK: - Backend Sync

    private func syncSubscriptionWithBackend(transaction: Transaction) async {
        // Get the receipt data
        guard let receiptData = await getReceiptData() else {
            print("❌ Failed to get receipt data")
            return
        }

        do {
            struct VerifyRequest: Encodable {
                let receiptData: String
                let transactionId: String
                let productId: String
            }

            let request = VerifyRequest(
                receiptData: receiptData,
                transactionId: String(transaction.id),
                productId: transaction.productID
            )

            struct VerifyResponse: Decodable {
                let success: Bool
                let tier: String
            }

            let response: VerifyResponse = try await APIClient.shared.send(
                path: "/v1/subscriptions/verify",
                method: "POST",
                body: request,
                requiresAuth: true,
                responseType: VerifyResponse.self
            )

            if response.success {
                print("✅ Subscription synced with backend: \(response.tier)")
            }
        } catch {
            print("❌ Failed to sync subscription with backend: \(error)")
        }
    }

    private func getReceiptData() async -> String? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            return nil
        }
        return receiptData.base64EncodedString()
    }
}

// MARK: - Errors

enum SubscriptionError: Error {
    case failedVerification
}

extension SubscriptionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        }
    }
}
