import Foundation

// Usage response from API
struct UsageResponse: Codable {
    let tier: String
    let date: String
    let usage: UsageData
    let limits: LimitsData
    let remaining: RemainingData
    let features: FeaturesData
}

struct UsageData: Codable {
    let nuggetsCreated: Int
    let swipeSessionsStarted: Int
}

struct LimitsData: Codable {
    let dailyNuggets: Int
    let dailySwipeSessions: Int
    let maxRSSFeeds: Int
    let maxCustomRSSFeeds: Int
    let maxFriends: Int
}

struct RemainingData: Codable {
    let nuggets: Int
    let swipeSessions: Int
}

struct FeaturesData: Codable {
    let hasAutoProcess: Bool
    let hasRSSSupport: Bool
    let hasCustomDigests: Bool
    let hasOfflineMode: Bool
    let hasReaderMode: Bool
    let hasNotificationConfig: Bool
}

// Error for limit exceeded
struct LimitExceededError: Codable {
    let error: String
    let code: String
    let limit: Int
    let used: Int
    let tier: String
    let message: String
}

final class UsageService {
    static let shared = UsageService()

    private init() {}

    // Get current usage and limits
    func getUsage() async throws -> UsageResponse {
        return try await APIClient.shared.send(
            path: "/usage",
            method: "GET",
            requiresAuth: true,
            responseType: UsageResponse.self
        )
    }

    // Check if user can create more nuggets
    func canCreateNugget() async -> (canCreate: Bool, remaining: Int, limit: Int) {
        do {
            let usage = try await getUsage()
            let remaining = usage.remaining.nuggets
            let limit = usage.limits.dailyNuggets

            // -1 means unlimited
            if limit == -1 {
                return (true, -1, -1)
            }

            return (remaining > 0, remaining, limit)
        } catch {
            // On error, allow creation (backend will enforce)
            return (true, -1, -1)
        }
    }

    // Check if user can start more swipe sessions
    func canStartSwipeSession() async -> (canStart: Bool, remaining: Int, limit: Int) {
        do {
            let usage = try await getUsage()
            let remaining = usage.remaining.swipeSessions
            let limit = usage.limits.dailySwipeSessions

            // -1 means unlimited
            if limit == -1 {
                return (true, -1, -1)
            }

            return (remaining > 0, remaining, limit)
        } catch {
            // On error, allow (backend will enforce)
            return (true, -1, -1)
        }
    }
}
