import Foundation

struct APIConfig {
    static var baseURL: URL {
        // For dev/testing, this can be overridden via environment variable
        if let urlString = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: urlString) {
            return url
        }

        // Try custom domain first, fallback to API Gateway
        #if DEBUG
        // For development, use direct API Gateway URL
        return URL(string: "https://1wk38vfbl2.execute-api.eu-west-1.amazonaws.com/v1")!
        #else
        // For production, try custom domain first
        if let customURL = URL(string: "https://api.nugget.jasontesting.com/v1") {
            return customURL
        }
        // Fallback to API Gateway
        return URL(string: "https://1wk38vfbl2.execute-api.eu-west-1.amazonaws.com/v1")!
        #endif
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
