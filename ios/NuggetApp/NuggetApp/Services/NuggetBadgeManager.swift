import Foundation
import SwiftUI

/// Manages badge count for new/unread processed nuggets
@MainActor
final class NuggetBadgeManager: ObservableObject {
    static let shared = NuggetBadgeManager()

    /// Number of new nuggets ready to read (unread, fully processed)
    @Published var unreadCount: Int = 0

    /// IDs of nuggets the user has seen (stored locally)
    @AppStorage("seenNuggetIds") private var seenNuggetIdsData: Data = Data()

    private var seenNuggetIds: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: seenNuggetIdsData)) ?? []
        }
        set {
            seenNuggetIdsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    private init() {}

    /// Updates the badge count based on processed nuggets
    /// - Parameter nuggets: All nuggets from the API
    func updateBadgeCount(with nuggets: [Nugget]) {
        // Only count nuggets that are:
        // 1. Fully processed (have a summary)
        // 2. Not yet seen by the user
        let processedNuggets = nuggets.filter { $0.summary != nil }
        let unseenProcessedNuggets = processedNuggets.filter { !seenNuggetIds.contains($0.nuggetId) }

        unreadCount = unseenProcessedNuggets.count
    }

    /// Marks a nugget as seen (removes from badge count)
    func markAsSeen(_ nuggetId: String) {
        var ids = seenNuggetIds
        ids.insert(nuggetId)
        seenNuggetIds = ids

        // Decrement count if > 0
        if unreadCount > 0 {
            unreadCount -= 1
        }
    }

    /// Marks all current nuggets as seen
    func markAllAsSeen(_ nuggets: [Nugget]) {
        var ids = seenNuggetIds
        for nugget in nuggets where nugget.summary != nil {
            ids.insert(nugget.nuggetId)
        }
        seenNuggetIds = ids
        unreadCount = 0
    }

    /// Checks if a nugget has been seen
    func hasBeenSeen(_ nuggetId: String) -> Bool {
        seenNuggetIds.contains(nuggetId)
    }

    /// Clears all seen data (for logout/account deletion)
    func clearAll() {
        seenNuggetIds = []
        unreadCount = 0
    }
}
