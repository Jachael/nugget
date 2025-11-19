import Foundation

class PreferencesService {
    static let shared = PreferencesService()
    private init() {}

    func getPreferences() async throws -> UserPreferences {
        return try await APIClient.shared.send(
            path: "/preferences",
            method: "GET",
            requiresAuth: true,
            responseType: UserPreferences.self
        )
    }

    func updatePreferences(_ preferences: UserPreferences) async throws -> UserPreferences {
        struct UpdatePreferencesRequest: Encodable {
            let interests: [String]
            let dailyNuggetLimit: Int
            let subscriptionTier: String
            let customCategories: [String]?
            let categoryWeights: [String: Double]?
        }

        let request = UpdatePreferencesRequest(
            interests: preferences.interests,
            dailyNuggetLimit: preferences.dailyNuggetLimit,
            subscriptionTier: preferences.subscriptionTier.rawValue,
            customCategories: preferences.customCategories,
            categoryWeights: preferences.categoryWeights
        )

        return try await APIClient.shared.send(
            path: "/preferences",
            method: "PUT",
            body: request,
            requiresAuth: true,
            responseType: UserPreferences.self
        )
    }

    func processNuggets(nuggetIds: [String]? = nil) async throws {
        struct ProcessNuggetsRequest: Encodable {
            let nuggetIds: [String]?
        }

        struct ProcessNuggetsResponse: Decodable {
            let message: String
            let processedCount: Int
            let nuggetIds: [String]?
        }

        let request = ProcessNuggetsRequest(nuggetIds: nuggetIds)

        let _ = try await APIClient.shared.send(
            path: "/nuggets/process",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: ProcessNuggetsResponse.self
        )
    }
}
