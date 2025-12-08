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
        case pro
        case ultimate
        case premium // Legacy, maps to pro

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            switch rawValue {
            case "free": self = .free
            case "pro": self = .pro
            case "ultimate": self = .ultimate
            case "premium": self = .pro // Legacy mapping
            default: self = .free
            }
        }
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
