import Foundation
import SwiftData

/// Offline cached nugget for Ultimate users
/// Stores nuggets locally for offline reading
@Model
final class OfflineNugget {
    @Attribute(.unique) var nuggetId: String
    var title: String?
    var summary: String?
    var keyPoints: [String]?
    var question: String?
    var sourceUrl: String
    var category: String?
    var fullContent: String? // Full article content for offline reading
    var cachedAt: Date
    var lastAccessedAt: Date

    // Grouped nugget data
    var isGrouped: Bool
    var sourceUrls: [String]?

    init(
        nuggetId: String,
        title: String? = nil,
        summary: String? = nil,
        keyPoints: [String]? = nil,
        question: String? = nil,
        sourceUrl: String,
        category: String? = nil,
        fullContent: String? = nil,
        isGrouped: Bool = false,
        sourceUrls: [String]? = nil
    ) {
        self.nuggetId = nuggetId
        self.title = title
        self.summary = summary
        self.keyPoints = keyPoints
        self.question = question
        self.sourceUrl = sourceUrl
        self.category = category
        self.fullContent = fullContent
        self.cachedAt = Date()
        self.lastAccessedAt = Date()
        self.isGrouped = isGrouped
        self.sourceUrls = sourceUrls
    }
}

/// Extension to convert from API Nugget model
extension OfflineNugget {
    convenience init(from nugget: Nugget) {
        self.init(
            nuggetId: nugget.id,
            title: nugget.title,
            summary: nugget.summary,
            keyPoints: nugget.keyPoints,
            question: nugget.question,
            sourceUrl: nugget.sourceUrl,
            category: nugget.category,
            fullContent: nil, // Will be fetched separately if needed
            isGrouped: nugget.isGrouped ?? false,
            sourceUrls: nugget.sourceUrls
        )
    }

    func toNugget() -> Nugget {
        Nugget(
            nuggetId: nuggetId,
            sourceUrl: sourceUrl,
            sourceType: "url",
            title: title,
            category: category,
            status: "completed",
            processingState: "ready",
            summary: summary,
            keyPoints: keyPoints,
            question: question,
            createdAt: cachedAt,
            lastReviewedAt: lastAccessedAt,
            timesReviewed: 0,
            isGrouped: isGrouped,
            sourceUrls: sourceUrls
        )
    }
}

/// Offline storage settings
struct OfflineSettings: Codable {
    var isEnabled: Bool
    var storageLimitMB: Int
    var autoCache: Bool // Auto-cache completed nuggets

    static let `default` = OfflineSettings(
        isEnabled: false,
        storageLimitMB: 100,
        autoCache: true
    )
}
