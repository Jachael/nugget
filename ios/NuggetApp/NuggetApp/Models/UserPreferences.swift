import Foundation

struct UserPreferences: Codable, Equatable {
    var interests: [String]
    var dailyNuggetLimit: Int
    var subscriptionTier: SubscriptionTier
    var customCategories: [String]?
    var categoryWeights: [String: Double]?
    var onboardingCompleted: Bool

    enum SubscriptionTier: String, Codable {
        case free
        case premium
    }

    static let defaultCategories = [
        "sport",
        "finance",
        "technology",
        "career",
        "health",
        "science",
        "business",
        "entertainment",
        "politics",
        "education"
    ]

    static let `default` = UserPreferences(
        interests: [],
        dailyNuggetLimit: 1,
        subscriptionTier: .free,
        customCategories: nil,
        categoryWeights: nil,
        onboardingCompleted: false
    )
}
