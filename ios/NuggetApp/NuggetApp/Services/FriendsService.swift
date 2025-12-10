import Foundation

// MARK: - Models

struct FriendsListResponse: Codable {
    let friends: [Friend]
    let count: Int
}

struct Friend: Codable, Identifiable {
    let userId: String
    let displayName: String
    let friendCode: String?

    var id: String { userId }
}

struct FriendCodeResponse: Codable {
    let friendCode: String
}

struct FriendRequest: Codable, Identifiable {
    let requestId: String
    let fromDisplayName: String
    let requestedAt: String

    var id: String { requestId }
}

struct FriendRequestsResponse: Codable {
    let requests: [FriendRequest]
}

struct SendFriendRequestResponse: Codable {
    let success: Bool
    let message: String
}

struct AcceptDeclineResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Shared Nuggets Models

struct SharedNugget: Codable, Identifiable {
    let shareId: String
    let nuggetId: String
    let senderUserId: String
    let senderDisplayName: String
    let sharedAt: String
    let isRead: Bool
    let title: String?
    let summary: String?
    let sourceUrl: String?
    let category: String?

    var id: String { shareId }
}

struct SharedNuggetsResponse: Codable {
    let sharedNuggets: [SharedNugget]
    let total: Int
    let unreadCount: Int
}

struct ShareToFriendsResponse: Codable {
    let success: Bool
    let message: String
    let sharedCount: Int
    let failedCount: Int
}

// MARK: - Friends Service

final class FriendsService {
    static let shared = FriendsService()

    private init() {}

    // Get my friend code
    func getFriendCode() async throws -> String {
        let response = try await APIClient.shared.send(
            path: "/friends/code",
            method: "GET",
            requiresAuth: true,
            responseType: FriendCodeResponse.self
        )
        return response.friendCode
    }

    // List all friends
    func listFriends() async throws -> [Friend] {
        let response = try await APIClient.shared.send(
            path: "/friends",
            method: "GET",
            requiresAuth: true,
            responseType: FriendsListResponse.self
        )
        return response.friends
    }

    // Send friend request by code
    func sendFriendRequest(friendCode: String) async throws -> String {
        struct RequestBody: Encodable {
            let friendCode: String
        }

        let response = try await APIClient.shared.send(
            path: "/friends/add",
            method: "POST",
            body: RequestBody(friendCode: friendCode),
            requiresAuth: true,
            responseType: SendFriendRequestResponse.self
        )
        return response.message
    }

    // List pending friend requests
    func listFriendRequests() async throws -> [FriendRequest] {
        let response = try await APIClient.shared.send(
            path: "/friends/requests",
            method: "GET",
            requiresAuth: true,
            responseType: FriendRequestsResponse.self
        )
        return response.requests
    }

    // Accept friend request
    func acceptFriendRequest(requestId: String) async throws {
        let _ = try await APIClient.shared.send(
            path: "/friends/requests/\(requestId)/accept",
            method: "POST",
            requiresAuth: true,
            responseType: AcceptDeclineResponse.self
        )
    }

    // Decline friend request
    func declineFriendRequest(requestId: String) async throws {
        let _ = try await APIClient.shared.send(
            path: "/friends/requests/\(requestId)/decline",
            method: "POST",
            requiresAuth: true,
            responseType: AcceptDeclineResponse.self
        )
    }

    // Remove friend
    func removeFriend(friendId: String) async throws {
        let _ = try await APIClient.shared.send(
            path: "/friends/\(friendId)",
            method: "DELETE",
            requiresAuth: true,
            responseType: AcceptDeclineResponse.self
        )
    }

    // MARK: - Sharing Nuggets

    // Share a nugget to friends
    func shareNuggetToFriends(nuggetId: String, friendIds: [String]) async throws -> ShareToFriendsResponse {
        struct RequestBody: Encodable {
            let friendIds: [String]
        }

        return try await APIClient.shared.send(
            path: "/nuggets/\(nuggetId)/share-to-friends",
            method: "POST",
            body: RequestBody(friendIds: friendIds),
            requiresAuth: true,
            responseType: ShareToFriendsResponse.self
        )
    }

    // Get nuggets shared with me
    func getSharedWithMe() async throws -> SharedNuggetsResponse {
        return try await APIClient.shared.send(
            path: "/shared-with-me",
            method: "GET",
            requiresAuth: true,
            responseType: SharedNuggetsResponse.self
        )
    }

    // Mark shared nugget as read
    func markSharedAsRead(shareId: String) async throws {
        let _ = try await APIClient.shared.send(
            path: "/shared-with-me/\(shareId)/read",
            method: "POST",
            requiresAuth: true,
            responseType: AcceptDeclineResponse.self
        )
    }
}
