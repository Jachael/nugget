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
    let nuggets: [FeedNugget]
    let errors: [FeedError]?
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
}
