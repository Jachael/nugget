import Foundation

struct Session: Codable {
    let sessionId: String
    let nuggets: [Nugget]
}

struct StartSessionRequest: Codable {
    let size: Int
    let category: String?
}

struct CompleteSessionRequest: Codable {
    let completedNuggetIds: [String]
}

struct CompleteSessionResponse: Codable {
    let success: Bool
    let completedCount: Int
}
