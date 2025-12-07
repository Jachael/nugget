import Foundation

// MARK: - Feed Models
struct RSSFeed: Identifiable, Codable {
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
    let catalog: [RSSFeed]
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
        let response: GetFeedsResponse = try await APIClient.shared.request(
            endpoint: "/v1/feeds",
            method: "GET"
        )
        return response
    }

    /// Subscribe or unsubscribe from a feed
    func subscribeFeed(rssFeedId: String, subscribe: Bool) async throws -> SubscribeFeedResponse {
        let request = SubscribeFeedRequest(rssFeedId: rssFeedId, subscribe: subscribe)
        let response: SubscribeFeedResponse = try await APIClient.shared.request(
            endpoint: "/v1/feeds/subscribe",
            method: "POST",
            body: request
        )
        return response
    }

    /// Fetch latest content from subscribed feeds
    func fetchFeedContent(feedId: String? = nil) async throws -> FetchFeedContentResponse {
        var endpoint = "/v1/feeds/fetch"
        if let feedId = feedId {
            endpoint += "?feedId=\(feedId)"
        }

        let response: FetchFeedContentResponse = try await APIClient.shared.request(
            endpoint: endpoint,
            method: "POST"
        )
        return response
    }

    /// Get feeds grouped by category
    func getFeedsByCategory(_ feeds: [RSSFeed]) -> [String: [RSSFeed]] {
        Dictionary(grouping: feeds, by: { $0.category })
    }
}
