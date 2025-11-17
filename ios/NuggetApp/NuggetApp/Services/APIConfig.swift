import Foundation

struct APIConfig {
    static var baseURL: URL {
        // For dev/testing, this can be overridden via environment variable
        if let urlString = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: urlString) {
            return url
        }
        // Production custom domain
        return URL(string: "https://api.nugget.jasontesting.com/v1")!
    }
}

enum APIError: Error {
    case invalidResponse
    case unauthorized
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)
}
