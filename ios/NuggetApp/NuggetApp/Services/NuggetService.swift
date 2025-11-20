import Foundation

final class NuggetService {
    static let shared = NuggetService()

    private init() {}

    /// Process any pending nuggets from the share extension
    /// Returns true if there were pending nuggets processed
    @discardableResult
    func processPendingSharedNuggets() async throws -> Bool {
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

        return response.nuggets
    }

    func startSession(size: Int = 3, category: String? = nil) async throws -> Session {
        let request = StartSessionRequest(size: size, category: category)
        return try await APIClient.shared.send(
            path: "/sessions/start",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: Session.self
        )
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
}
