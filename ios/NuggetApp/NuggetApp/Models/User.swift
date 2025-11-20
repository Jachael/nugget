import Foundation

struct User: Codable {
    let userId: String
    let accessToken: String
    let streak: Int
    let firstName: String?
}

struct AuthResponse: Codable {
    let userId: String
    let accessToken: String
    let streak: Int
    let firstName: String?
}
