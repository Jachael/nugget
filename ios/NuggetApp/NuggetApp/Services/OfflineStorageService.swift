import Foundation
import SwiftData

/// Service for managing offline nugget storage
/// Available only for Ultimate tier users
@MainActor
final class OfflineStorageService: ObservableObject {
    static let shared = OfflineStorageService()

    @Published var cachedNuggetCount: Int = 0
    @Published var storageUsedMB: Double = 0
    @Published var isEnabled: Bool = false

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    private let settingsKey = "offlineSettings"

    private init() {
        setupSwiftData()
        loadSettings()
        updateCacheStats()
    }

    // MARK: - Setup

    private func setupSwiftData() {
        do {
            let schema = Schema([OfflineNugget.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = modelContainer?.mainContext
        } catch {
            print("Failed to setup SwiftData: \(error)")
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(OfflineSettings.self, from: data) {
            isEnabled = settings.isEnabled
        }
    }

    func saveSettings(_ settings: OfflineSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
            isEnabled = settings.isEnabled
        }
    }

    func getSettings() -> OfflineSettings {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(OfflineSettings.self, from: data) {
            return settings
        }
        return .default
    }

    // MARK: - Cache Operations

    /// Cache a nugget for offline reading
    func cacheNugget(_ nugget: Nugget) {
        guard let context = modelContext else { return }

        // Check if already cached
        let nuggetId = nugget.id
        let descriptor = FetchDescriptor<OfflineNugget>(
            predicate: #Predicate { $0.nuggetId == nuggetId }
        )

        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                let offlineNugget = OfflineNugget(from: nugget)
                context.insert(offlineNugget)
                try context.save()
                updateCacheStats()
                print("Cached nugget: \(nugget.id)")
            } else {
                // Update access time
                existing.first?.lastAccessedAt = Date()
                try context.save()
            }
        } catch {
            print("Failed to cache nugget: \(error)")
        }
    }

    /// Get a cached nugget by ID
    func getCachedNugget(id: String) -> OfflineNugget? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<OfflineNugget>(
            predicate: #Predicate { $0.nuggetId == id }
        )

        do {
            let results = try context.fetch(descriptor)
            if let nugget = results.first {
                nugget.lastAccessedAt = Date()
                try context.save()
                return nugget
            }
        } catch {
            print("Failed to get cached nugget: \(error)")
        }
        return nil
    }

    /// Get all cached nuggets
    func getAllCachedNuggets() -> [OfflineNugget] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<OfflineNugget>(
            sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to get cached nuggets: \(error)")
            return []
        }
    }

    /// Check if a nugget is cached
    func isNuggetCached(id: String) -> Bool {
        guard let context = modelContext else { return false }

        let descriptor = FetchDescriptor<OfflineNugget>(
            predicate: #Predicate { $0.nuggetId == id }
        )

        do {
            let count = try context.fetchCount(descriptor)
            return count > 0
        } catch {
            return false
        }
    }

    /// Remove a cached nugget
    func removeCachedNugget(id: String) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<OfflineNugget>(
            predicate: #Predicate { $0.nuggetId == id }
        )

        do {
            let results = try context.fetch(descriptor)
            for nugget in results {
                context.delete(nugget)
            }
            try context.save()
            updateCacheStats()
            print("Removed cached nugget: \(id)")
        } catch {
            print("Failed to remove cached nugget: \(error)")
        }
    }

    /// Clear all cached nuggets
    func clearAllCache() {
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<OfflineNugget>()
            let all = try context.fetch(descriptor)
            for nugget in all {
                context.delete(nugget)
            }
            try context.save()
            updateCacheStats()
            print("Cleared all cached nuggets")
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }

    /// Clean up old cached nuggets to stay within storage limit
    func cleanupOldCache(limitMB: Int = 100) {
        guard let context = modelContext else { return }

        // Get all nuggets sorted by last accessed (oldest first)
        let descriptor = FetchDescriptor<OfflineNugget>(
            sortBy: [SortDescriptor(\.lastAccessedAt, order: .forward)]
        )

        do {
            let all = try context.fetch(descriptor)

            // Estimate storage and remove old items if over limit
            var totalSize: Int64 = 0
            let limitBytes = Int64(limitMB * 1024 * 1024)

            // Calculate estimated size
            for nugget in all {
                let size = estimateNuggetSize(nugget)
                totalSize += size
            }

            // Remove oldest until under limit
            var removed = 0
            for nugget in all {
                if totalSize <= limitBytes {
                    break
                }
                let size = estimateNuggetSize(nugget)
                context.delete(nugget)
                totalSize -= size
                removed += 1
            }

            if removed > 0 {
                try context.save()
                print("Cleaned up \(removed) old cached nuggets")
                updateCacheStats()
            }
        } catch {
            print("Failed to cleanup cache: \(error)")
        }
    }

    // MARK: - Stats

    private func updateCacheStats() {
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<OfflineNugget>()
            let all = try context.fetch(descriptor)

            cachedNuggetCount = all.count

            var totalSize: Int64 = 0
            for nugget in all {
                totalSize += estimateNuggetSize(nugget)
            }

            storageUsedMB = Double(totalSize) / (1024 * 1024)
        } catch {
            cachedNuggetCount = 0
            storageUsedMB = 0
        }
    }

    private func estimateNuggetSize(_ nugget: OfflineNugget) -> Int64 {
        var size: Int64 = 0

        size += Int64((nugget.title ?? "").utf8.count)
        size += Int64((nugget.summary ?? "").utf8.count)
        size += Int64((nugget.question ?? "").utf8.count)
        size += Int64((nugget.fullContent ?? "").utf8.count)
        size += Int64(nugget.sourceUrl.utf8.count)
        size += Int64((nugget.category ?? "").utf8.count)

        if let keyPoints = nugget.keyPoints {
            for point in keyPoints {
                size += Int64(point.utf8.count)
            }
        }

        if let urls = nugget.sourceUrls {
            for url in urls {
                size += Int64(url.utf8.count)
            }
        }

        // Add overhead for object structure
        size += 500

        return size
    }

    /// Get formatted storage used string
    var storageUsedFormatted: String {
        if storageUsedMB < 1 {
            return String(format: "%.0f KB", storageUsedMB * 1024)
        }
        return String(format: "%.1f MB", storageUsedMB)
    }
}
