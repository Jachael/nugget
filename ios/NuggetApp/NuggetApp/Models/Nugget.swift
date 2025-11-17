import Foundation

struct Nugget: Identifiable, Codable {
    let nuggetId: String
    let sourceUrl: String
    let sourceType: String
    var title: String?
    var category: String?
    var status: String
    var summary: String?
    var keyPoints: [String]?
    var question: String?
    let createdAt: Date
    var lastReviewedAt: Date?
    var timesReviewed: Int

    var id: String { nuggetId }

    enum CodingKeys: String, CodingKey {
        case nuggetId
        case sourceUrl
        case sourceType
        case title
        case category
        case status
        case summary
        case keyPoints
        case question
        case createdAt
        case lastReviewedAt
        case timesReviewed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nuggetId = try container.decode(String.self, forKey: .nuggetId)
        sourceUrl = try container.decode(String.self, forKey: .sourceUrl)
        sourceType = try container.decode(String.self, forKey: .sourceType)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        status = try container.decode(String.self, forKey: .status)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        keyPoints = try container.decodeIfPresent([String].self, forKey: .keyPoints)
        question = try container.decodeIfPresent(String.self, forKey: .question)
        timesReviewed = try container.decode(Int.self, forKey: .timesReviewed)

        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let lastReviewedAtString = try container.decodeIfPresent(String.self, forKey: .lastReviewedAt)

        let formatter = ISO8601DateFormatter()
        createdAt = formatter.date(from: createdAtString) ?? Date()
        if let lastReviewedAtString = lastReviewedAtString {
            lastReviewedAt = formatter.date(from: lastReviewedAtString)
        }
    }
}

struct CreateNuggetRequest: Codable {
    let sourceUrl: String
    let sourceType: String
    let rawTitle: String?
    let rawText: String?
    let category: String?
}

struct NuggetsResponse: Codable {
    let nuggets: [Nugget]
}
