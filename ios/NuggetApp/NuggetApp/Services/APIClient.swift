import Foundation

final class APIClient {
    static let shared = APIClient()

    private init() {}

    private func createRequest(
        path: String,
        method: String,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = false
    ) throws -> URLRequest {
        let url = APIConfig.baseURL.appendingPathComponent(path)
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

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

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
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
}
