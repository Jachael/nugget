import Foundation

struct Session: Codable, Identifiable, Hashable {
    let sessionId: String
    let nuggets: [Nugget]

    var id: String { sessionId }

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.sessionId == rhs.sessionId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sessionId)
    }
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
