import Foundation

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession

    private init() {
        // Configure URLSession for better performance
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024, // 10 MB memory cache
            diskCapacity: 50 * 1024 * 1024,   // 50 MB disk cache
            diskPath: "nugget_cache"
        )
        configuration.httpMaximumConnectionsPerHost = 5

        self.session = URLSession(configuration: configuration)
    }

    private func createRequest(
        path: String,
        method: String,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = false
    ) throws -> URLRequest {
        // Handle query parameters properly
        let urlString = APIConfig.baseURL.absoluteString + path
        guard let url = URL(string: urlString) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let token = KeychainManager.shared.getToken() else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }

    func send<T: Decodable>(
        path: String,
        method: String,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = false,
        responseType: T.Type
    ) async throws -> T {
        let request = try createRequest(path: path, method: method, body: body, requiresAuth: requiresAuth)

        #if DEBUG
        print("📡 API Request: \(method) \(request.url?.absoluteString ?? "unknown")")
        #endif

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            #if DEBUG
            print("📥 Response: \(httpResponse.statusCode)")
            #endif

            guard (200..<300).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(errorMessage)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)

        } catch let error as APIError {
            print("❌ API Error: \(error)")
            throw error
        } catch let error as DecodingError {
            print("❌ Decoding Error: \(error)")
            throw APIError.decodingError(error)
        } catch {
            print("❌ Network Error: \(error)")
            throw APIError.networkError(error)
        }
    }
}
