import Foundation

final class ProcessingService {
    static let shared = ProcessingService()

    private init() {}

    func setSchedule(request: SetProcessingScheduleRequest) async throws -> SetProcessingScheduleResponse {
        return try await APIClient.shared.send(
            path: "/processing/schedule",
            method: "POST",
            body: request,
            requiresAuth: true,
            responseType: SetProcessingScheduleResponse.self
        )
    }

    func getSchedule() async throws -> ProcessingScheduleInfo {
        return try await APIClient.shared.send(
            path: "/processing/schedule",
            method: "GET",
            requiresAuth: true,
            responseType: ProcessingScheduleInfo.self
        )
    }
}

// MARK: - Request/Response Models

struct SetProcessingScheduleRequest: Codable {
    let enabled: Bool
    let frequency: String?
    let preferredTime: String?
    let timezone: String?
}

struct SetProcessingScheduleResponse: Codable {
    let message: String
    let schedule: ProcessingScheduleInfo?
}

struct ProcessingScheduleInfo: Codable {
    let scheduleId: String
    let frequency: String
    let preferredTime: String
    let timezone: String
    let enabled: Bool
    let nextRun: String?
}
