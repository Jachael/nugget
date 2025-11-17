import Foundation

struct User: Codable {
    let userId: String
    let accessToken: String
    let streak: Int
}

struct AuthResponse: Codable {
    let userId: String
    let accessToken: String
    let streak: Int
}
