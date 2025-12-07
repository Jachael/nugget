import Foundation

struct User: Codable {
    let userId: String
    let accessToken: String
    let streak: Int
    let firstName: String?
    let subscriptionTier: String?
    let subscriptionExpiresAt: String?
}

struct AuthResponse: Codable {
    let userId: String
    let accessToken: String
    let streak: Int
    let firstName: String?
    let subscriptionTier: String?
    let subscriptionExpiresAt: String?
}
