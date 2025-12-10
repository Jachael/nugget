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
    let intervalHours: Int? // Ultimate tier only: 2, 4, 6, 8, or 12
}

struct SetProcessingScheduleResponse: Codable {
    let message: String
    let schedule: ProcessingScheduleInfo?
    let enabled: Bool?
}

struct ProcessingScheduleInfo: Codable {
    let scheduleId: String?
    let frequency: String?
    let preferredTime: String?
    let timezone: String?
    let enabled: Bool
    let nextRun: String?
    let processingMode: String? // 'windows' (Pro) or 'interval' (Ultimate)
    let intervalHours: Int?     // Ultimate only
    let tier: String?           // 'pro' or 'ultimate'
}

// Valid interval options for Ultimate tier
enum ProcessingInterval: Int, CaseIterable, Identifiable {
    case every2Hours = 2
    case every4Hours = 4
    case every6Hours = 6
    case every8Hours = 8
    case every12Hours = 12

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .every2Hours: return "Every 2 hours"
        case .every4Hours: return "Every 4 hours"
        case .every6Hours: return "Every 6 hours"
        case .every8Hours: return "Every 8 hours"
        case .every12Hours: return "Every 12 hours"
        }
    }

    var description: String {
        switch self {
        case .every2Hours: return "12 times per day"
        case .every4Hours: return "6 times per day"
        case .every6Hours: return "4 times per day"
        case .every8Hours: return "3 times per day"
        case .every12Hours: return "Twice per day"
        }
    }
}
