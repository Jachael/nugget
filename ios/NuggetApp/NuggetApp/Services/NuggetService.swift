import Foundation

final class NuggetService {
    static let shared = NuggetService()

    private init() {}

    func createNugget(request: CreateNuggetRequest) async throws -> Nugget {
        return try await APIClient.shared.send(
            path: "/nuggets",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: Nugget.self
        )
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
}
