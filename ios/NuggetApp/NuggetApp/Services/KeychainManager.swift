import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.nugget.app"
    private let tokenKey = "accessToken"
    private let userIdKey = "userId"

    private init() {}

    func saveToken(_ token: String) {
        save(key: tokenKey, value: token)
    }

    func getToken() -> String? {
        return get(key: tokenKey)
    }

    func saveUserId(_ userId: String) {
        save(key: userIdKey, value: userId)
    }

    func getUserId() -> String? {
        return get(key: userIdKey)
    }

    func clearAll() {
        delete(key: tokenKey)
        delete(key: userIdKey)
    }

    private func save(key: String, value: String) {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
