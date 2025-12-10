import Foundation

// MARK: - Feed Models
struct CatalogFeed: Identifiable, Codable {
    let id: String
    let name: String
    let url: String
    let category: String
    let description: String
    let isPremium: Bool
    var isSubscribed: Bool
}

struct FeedSubscription: Identifiable, Codable {
    let feedId: String
    let rssFeedId: String
    let feedName: String
    let category: String
    let isActive: Bool
    let subscribedAt: String

    var id: String { feedId }
}

struct GetFeedsResponse: Codable {
    let catalog: [CatalogFeed]
    let subscriptions: [FeedSubscription]
}

struct SubscribeFeedRequest: Codable {
    let rssFeedId: String
    let subscribe: Bool
}

struct SubscribeFeedResponse: Codable {
    let message: String
    let subscription: FeedSubscription?
}

struct FetchFeedContentResponse: Codable {
    let message: String
    let feedCount: Int?  // Async response returns this
    let nuggets: [FeedNugget]?  // Old sync response returned this
    let errors: [FeedError]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(String.self, forKey: .message)
        feedCount = try container.decodeIfPresent(Int.self, forKey: .feedCount)
        nuggets = try container.decodeIfPresent([FeedNugget].self, forKey: .nuggets)
        errors = try container.decodeIfPresent([FeedError].self, forKey: .errors)
    }

    private enum CodingKeys: String, CodingKey {
        case message, feedCount, nuggets, errors
    }
}

struct FeedNugget: Codable {
    let nuggetId: String
    let feedName: String
    let articleCount: Int
    let title: String
    let category: String
}

struct FeedError: Codable {
    let feedId: String
    let feedName: String
    let error: String
}

// MARK: - Custom Digest Models (Ultimate Only)

enum DigestFrequency: String, Codable, CaseIterable, Identifiable {
    case withSchedule = "with_schedule"
    case onceDaily = "once_daily"
    case twiceDaily = "twice_daily"
    case threeTimesDaily = "three_times_daily"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .withSchedule: return "With auto-processing"
        case .onceDaily: return "Once daily"
        case .twiceDaily: return "Twice daily"
        case .threeTimesDaily: return "3 times daily"
        }
    }

    var description: String {
        switch self {
        case .withSchedule: return "Generates when auto-processing runs"
        case .onceDaily: return "One digest per day"
        case .twiceDaily: return "Morning and evening"
        case .threeTimesDaily: return "Morning, afternoon, and evening"
        }
    }
}

enum ArticlesPerDigest: Int, Codable, CaseIterable, Identifiable {
    case three = 3
    case five = 5
    case ten = 10
    case fifteen = 15
    case twenty = 20

    var id: Int { rawValue }

    var displayName: String {
        "\(rawValue) articles"
    }
}

struct CustomDigest: Identifiable, Codable {
    let digestId: String
    let name: String
    let feedIds: [String]
    let isEnabled: Bool
    let lastGeneratedAt: String?
    let createdAt: String
    let articlesPerDigest: Int
    let frequency: DigestFrequency

    var id: String { digestId }

    // Handle missing fields from older records
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        digestId = try container.decode(String.self, forKey: .digestId)
        name = try container.decode(String.self, forKey: .name)
        feedIds = try container.decode([String].self, forKey: .feedIds)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        lastGeneratedAt = try container.decodeIfPresent(String.self, forKey: .lastGeneratedAt)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        articlesPerDigest = try container.decodeIfPresent(Int.self, forKey: .articlesPerDigest) ?? 5
        frequency = try container.decodeIfPresent(DigestFrequency.self, forKey: .frequency) ?? .withSchedule
    }
}

struct CreateDigestRequest: Codable {
    let name: String
    let feedIds: [String]
    let articlesPerDigest: Int?
    let frequency: DigestFrequency?
}

struct UpdateDigestRequest: Codable {
    let name: String?
    let feedIds: [String]?
    let isEnabled: Bool?
    let articlesPerDigest: Int?
    let frequency: DigestFrequency?
}

struct DigestResponse: Codable {
    let message: String
    let digest: CustomDigest?
}

struct ListDigestsResponse: Codable {
    let digests: [CustomDigest]
    let tier: String?
    let upgradeRequired: Bool?
    let limit: Int?
    let message: String?
}

struct DeleteDigestResponse: Codable {
    let message: String
    let digestId: String?
}

// MARK: - Custom RSS Feed Models (Ultimate Only)

struct CustomRSSFeed: Identifiable, Codable {
    let feedId: String
    let url: String
    let name: String
    let description: String?
    let iconUrl: String?
    let category: String?
    let createdAt: String
    let lastFetchedAt: String?
    let isValid: Bool

    var id: String { feedId }
}

struct AddCustomFeedRequest: Codable {
    let url: String
    let name: String?
    let category: String?
}

struct AddCustomFeedResponse: Codable {
    let feedId: String
    let url: String
    let name: String
    let description: String?
    let iconUrl: String?
    let category: String?
    let createdAt: String
    let articleCount: Int
}

struct ListCustomFeedsResponse: Codable {
    let feeds: [CustomRSSFeed]
    let count: Int
}

struct ValidateFeedResponse: Codable {
    let isValid: Bool
    let title: String?
    let description: String?
    let iconUrl: String?
    let articleCount: Int?
    let latestArticle: String?
    let error: String?
}

struct DeleteCustomFeedResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - Feed Service
final class FeedService {
    static let shared = FeedService()

    private init() {}

    /// Get all available feeds and user's subscriptions
    func getFeeds() async throws -> GetFeedsResponse {
        return try await APIClient.shared.send(
            path: "/feeds",
            method: "GET",
            requiresAuth: true,
            responseType: GetFeedsResponse.self
        )
    }

    /// Subscribe or unsubscribe from a feed
    func subscribeFeed(rssFeedId: String, subscribe: Bool) async throws -> SubscribeFeedResponse {
        let request = SubscribeFeedRequest(rssFeedId: rssFeedId, subscribe: subscribe)
        return try await APIClient.shared.send(
            path: "/feeds/subscribe",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: SubscribeFeedResponse.self
        )
    }

    /// Fetch latest content from subscribed feeds
    func fetchFeedContent(feedId: String? = nil) async throws -> FetchFeedContentResponse {
        var path = "/feeds/fetch"
        if let feedId = feedId {
            path += "?feedId=\(feedId)"
        }

        return try await APIClient.shared.send(
            path: path,
            method: "POST",
            requiresAuth: true,
            responseType: FetchFeedContentResponse.self
        )
    }

    /// Get feeds grouped by category
    func getFeedsByCategory(_ feeds: [CatalogFeed]) -> [String: [CatalogFeed]] {
        Dictionary(grouping: feeds, by: { $0.category })
    }

    // MARK: - Custom Digests (Ultimate Only)

    /// Get user's custom digests
    func getDigests() async throws -> ListDigestsResponse {
        return try await APIClient.shared.send(
            path: "/digests",
            method: "GET",
            requiresAuth: true,
            responseType: ListDigestsResponse.self
        )
    }

    /// Create a new custom digest
    func createDigest(
        name: String,
        feedIds: [String],
        articlesPerDigest: Int? = nil,
        frequency: DigestFrequency? = nil
    ) async throws -> DigestResponse {
        let request = CreateDigestRequest(
            name: name,
            feedIds: feedIds,
            articlesPerDigest: articlesPerDigest,
            frequency: frequency
        )
        return try await APIClient.shared.send(
            path: "/digests",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: DigestResponse.self
        )
    }

    /// Update an existing digest
    func updateDigest(
        digestId: String,
        name: String? = nil,
        feedIds: [String]? = nil,
        isEnabled: Bool? = nil,
        articlesPerDigest: Int? = nil,
        frequency: DigestFrequency? = nil
    ) async throws -> DigestResponse {
        let request = UpdateDigestRequest(
            name: name,
            feedIds: feedIds,
            isEnabled: isEnabled,
            articlesPerDigest: articlesPerDigest,
            frequency: frequency
        )
        return try await APIClient.shared.send(
            path: "/digests/\(digestId)",
            method: "PUT",
            body: request,
            requiresAuth: true,
            responseType: DigestResponse.self
        )
    }

    /// Delete a digest
    func deleteDigest(digestId: String) async throws -> DeleteDigestResponse {
        return try await APIClient.shared.send(
            path: "/digests/\(digestId)",
            method: "DELETE",
            requiresAuth: true,
            responseType: DeleteDigestResponse.self
        )
    }

    // MARK: - Manual Feed Fetch

    struct FetchAllResponse: Codable {
        let message: String
        let tier: String?
    }

    /// Manually trigger feed fetch including custom digests
    /// This runs the same process as the scheduled auto-fetch
    func fetchAllFeeds() async throws -> FetchAllResponse {
        return try await APIClient.shared.send(
            path: "/feeds/fetch-all",
            method: "POST",
            requiresAuth: true,
            responseType: FetchAllResponse.self
        )
    }

    // MARK: - Custom RSS Feeds (Ultimate Only)

    /// Get user's custom RSS feeds
    func getCustomFeeds() async throws -> ListCustomFeedsResponse {
        return try await APIClient.shared.send(
            path: "/feeds/custom",
            method: "GET",
            requiresAuth: true,
            responseType: ListCustomFeedsResponse.self
        )
    }

    /// Add a custom RSS feed
    func addCustomFeed(url: String, name: String? = nil, category: String? = nil) async throws -> AddCustomFeedResponse {
        let request = AddCustomFeedRequest(url: url, name: name, category: category)
        return try await APIClient.shared.send(
            path: "/feeds/custom",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: AddCustomFeedResponse.self
        )
    }

    /// Validate a feed URL before adding
    func validateFeedUrl(_ url: String) async throws -> ValidateFeedResponse {
        struct ValidateRequest: Codable {
            let url: String
        }
        return try await APIClient.shared.send(
            path: "/feeds/custom/validate",
            method: "POST",
            body: ValidateRequest(url: url),
            requiresAuth: true,
            responseType: ValidateFeedResponse.self
        )
    }

    /// Delete a custom RSS feed
    func deleteCustomFeed(feedId: String) async throws -> DeleteCustomFeedResponse {
        return try await APIClient.shared.send(
            path: "/feeds/custom/\(feedId)",
            method: "DELETE",
            requiresAuth: true,
            responseType: DeleteCustomFeedResponse.self
        )
    }
}
