import Foundation

struct APIConfig {
    static var baseURL: URL {
        // For dev/testing, this can be overridden via environment variable
        if let urlString = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: urlString) {
            return url
        }

        // Use direct API Gateway URL for now
        // Custom domain api.nugget.jasontesting.com points to an older API version
        return URL(string: "https://1wk38vfbl2.execute-api.eu-west-1.amazonaws.com/v1")!
    }
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized - please sign in again"
        case .serverError(let message):
            return message
        case .decodingError(let error):
            return "Data error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
