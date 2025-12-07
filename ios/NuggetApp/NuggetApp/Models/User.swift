import Foundation

struct User: Codable {
    let userId: String
    let accessToken: String
    let streak: Int
    let firstName: String?
    var subscriptionTier: String?
    var subscriptionExpiresAt: String?

    init(userId: String, accessToken: String, streak: Int, firstName: String?, subscriptionTier: String? = nil, subscriptionExpiresAt: String? = nil) {
        self.userId = userId
        self.accessToken = accessToken
        self.streak = streak
        self.firstName = firstName
        self.subscriptionTier = subscriptionTier
        self.subscriptionExpiresAt = subscriptionExpiresAt
    }
}

struct AuthResponse: Codable {
    let userId: String
    let accessToken: String
    let streak: Int
    let firstName: String?
    let subscriptionTier: String?
    let subscriptionExpiresAt: String?
}
