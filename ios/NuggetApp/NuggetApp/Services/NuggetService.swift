import Foundation

final class NuggetService {
    static let shared = NuggetService()

    /// Actor to prevent duplicate processing of shared nuggets
    private actor ProcessingState {
        var isProcessing = false

        func startProcessing() -> Bool {
            if isProcessing { return false }
            isProcessing = true
            return true
        }

        func stopProcessing() {
            isProcessing = false
        }
    }

    private let processingState = ProcessingState()

    private init() {}

    /// Check if offline auto-caching is enabled
    private var shouldAutoCache: Bool {
        let settings = UserDefaults.standard.data(forKey: "offlineSettings")
            .flatMap { try? JSONDecoder().decode(OfflineSettings.self, from: $0) }
            ?? .default
        return settings.isEnabled && settings.autoCache
    }

    /// Cache nuggets that are ready (have summaries) for offline use
    @MainActor
    private func autoCacheReadyNuggets(_ nuggets: [Nugget]) {
        guard shouldAutoCache else { return }

        let readyNuggets = nuggets.filter { $0.summary != nil }
        guard !readyNuggets.isEmpty else { return }

        Task {
            for nugget in readyNuggets {
                OfflineStorageService.shared.cacheNugget(nugget)
            }
            print("Auto-cached \(readyNuggets.count) ready nuggets for offline use")
        }
    }

    /// Process any pending nuggets from the share extension
    /// Returns true if there were pending nuggets processed
    @discardableResult
    func processPendingSharedNuggets() async throws -> Bool {
        // Prevent duplicate processing (race condition when app becomes active)
        guard await processingState.startProcessing() else {
            print("Already processing shared nuggets, skipping")
            return false
        }

        defer {
            Task { await processingState.stopProcessing() }
        }

        guard let sharedDefaults = UserDefaults(suiteName: "group.erg.NuggetApp") else {
            print("Failed to access shared UserDefaults")
            return false
        }

        guard let pendingNuggets = sharedDefaults.array(forKey: "pendingNuggets") as? [[String: Any]],
              !pendingNuggets.isEmpty else {
            print("No pending nuggets to process")
            return false
        }

        print("Found \(pendingNuggets.count) pending nuggets from share extension")

        // Process each pending nugget
        for nuggetData in pendingNuggets {
            guard let urlString = nuggetData["url"] as? String else { continue }

            do {
                // Create nugget via API
                let request = CreateNuggetRequest(
                    sourceUrl: urlString,
                    sourceType: "url",
                    rawTitle: nil,
                    rawText: nil,
                    category: nil
                )
                let nugget = try await createNugget(request: request)
                print("Successfully created nugget: \(nugget.id)")
            } catch {
                print("Failed to create nugget from shared URL: \(urlString), error: \(error)")
                // Continue processing other nuggets even if one fails
            }
        }

        // Clear the pending nuggets after processing
        sharedDefaults.removeObject(forKey: "pendingNuggets")
        sharedDefaults.synchronize()
        print("Cleared pending nuggets from shared storage")

        return true // We had pending nuggets
    }

    func createNugget(request: CreateNuggetRequest) async throws -> Nugget {
        return try await APIClient.shared.send(
            path: "/nuggets",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: Nugget.self
        )
    }

    func createNuggetFromURL(_ urlString: String) async throws -> Nugget {
        let request = CreateNuggetRequest(
            sourceUrl: urlString,
            sourceType: "url",
            rawTitle: nil,
            rawText: nil,
            category: nil
        )
        return try await createNugget(request: request)
    }

    func listNuggets(status: String = "inbox", category: String? = nil) async throws -> [Nugget] {
        var path = "/nuggets?status=\(status)"
        if let category = category {
            path += "&category=\(category)"
        }

        let response = try await APIClient.shared.send(
            path: path,
            method: "GET",
            requiresAuth: true,
            responseType: NuggetsResponse.self
        )

        // Auto-cache ready nuggets for offline use if enabled
        await autoCacheReadyNuggets(response.nuggets)

        return response.nuggets
    }

    func startSession(size: Int = 3, category: String? = nil) async throws -> Session {
        let request = StartSessionRequest(size: size, category: category)
        let session = try await APIClient.shared.send(
            path: "/sessions/start",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: Session.self
        )

        // Auto-cache session nuggets for offline use
        await autoCacheReadyNuggets(session.nuggets)

        return session
    }

    func createSmartSession(query: String, limit: Int = 5) async throws -> Session {
        struct SmartSessionRequest: Codable {
            let query: String
            let limit: Int
        }

        struct SmartSessionResponse: Codable {
            let sessionId: String
            let nuggets: [Nugget]
            let query: String
            let totalMatches: Int
            let processed: Int
        }

        let request = SmartSessionRequest(query: query, limit: limit)
        let response = try await APIClient.shared.send(
            path: "/sessions/smart",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: SmartSessionResponse.self
        )

        // Auto-cache session nuggets for offline use
        await autoCacheReadyNuggets(response.nuggets)

        // Convert to Session format
        return Session(
            sessionId: response.sessionId,
            nuggets: response.nuggets,
            message: nil
        )
    }

    func completeSession(sessionId: String, completedNuggetIds: [String]) async throws -> CompleteSessionResponse {
        let request = CompleteSessionRequest(completedNuggetIds: completedNuggetIds)
        return try await APIClient.shared.send(
            path: "/sessions/\(sessionId)/complete",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: CompleteSessionResponse.self
        )
    }

    /// Mark nuggets as read (for sessions without a sessionId)
    func markNuggetsRead(nuggetIds: [String]) async throws {
        struct MarkReadRequest: Codable {
            let nuggetIds: [String]
        }

        struct MarkReadResponse: Codable {
            let success: Bool
            let markedCount: Int
        }

        let request = MarkReadRequest(nuggetIds: nuggetIds)
        let _ = try await APIClient.shared.send(
            path: "/nuggets/mark-read",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: MarkReadResponse.self
        )
    }

    func deleteNugget(nuggetId: String) async throws {
        struct DeleteResponse: Codable {
            let success: Bool
        }

        let _ = try await APIClient.shared.send(
            path: "/nuggets/\(nuggetId)",
            method: "DELETE",
            requiresAuth: true,
            responseType: DeleteResponse.self
        )
    }

    /// Batch delete multiple nuggets
    func batchDeleteNuggets(nuggetIds: [String]) async throws -> Int {
        struct BatchDeleteRequest: Codable {
            let nuggetIds: [String]
        }

        struct BatchDeleteResponse: Codable {
            let success: Bool
            let deleted: Int
        }

        let request = BatchDeleteRequest(nuggetIds: nuggetIds)
        let response = try await APIClient.shared.send(
            path: "/nuggets/batch-delete",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: BatchDeleteResponse.self
        )
        return response.deleted
    }

    /// Delete all nuggets for the current user
    func deleteAllNuggets() async throws -> Int {
        struct DeleteAllRequest: Codable {
            let deleteAll: Bool
        }

        struct BatchDeleteResponse: Codable {
            let success: Bool
            let deleted: Int
        }

        let request = DeleteAllRequest(deleteAll: true)
        let response = try await APIClient.shared.send(
            path: "/nuggets/batch-delete",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: BatchDeleteResponse.self
        )
        return response.deleted
    }

    func shareNugget(nuggetId: String) async throws -> ShareNuggetResponse {
        struct EmptyBody: Codable {}

        return try await APIClient.shared.send(
            path: "/nuggets/\(nuggetId)/share",
            method: "POST",
            body: EmptyBody(),
            requiresAuth: true,
            responseType: ShareNuggetResponse.self
        )
    }
}

struct ShareNuggetResponse: Codable {
    let shareId: String
    let shareUrl: String
    let message: String
}
