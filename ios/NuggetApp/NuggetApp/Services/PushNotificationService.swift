import Foundation
import UserNotifications

enum NotificationCategory: String {
    case nuggetsReady = "NUGGETS_READY"
    case streakReminder = "STREAK_REMINDER"
    case newContent = "NEW_CONTENT"
}

class PushNotificationService: NSObject {
    static let shared = PushNotificationService()

    private override init() {
        super.init()
    }

    // Request notification permissions
    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()

        // Define notification categories
        let nuggetsReadyCategory = UNNotificationCategory(
            identifier: NotificationCategory.nuggetsReady.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let streakReminderCategory = UNNotificationCategory(
            identifier: NotificationCategory.streakReminder.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let newContentCategory = UNNotificationCategory(
            identifier: NotificationCategory.newContent.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        // Set the categories
        center.setNotificationCategories([
            nuggetsReadyCategory,
            streakReminderCategory,
            newContentCategory
        ])

        // Request authorization
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        if granted {
            print("Notification permission granted")
        } else {
            print("Notification permission denied")
        }

        return granted
    }

    // Register for remote notifications
    @MainActor
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // Send device token to backend
    func sendTokenToBackend(deviceToken: String) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/v1/device/register") else {
            throw URLError(.badURL)
        }

        let payload: [String: Any] = [
            "deviceToken": deviceToken,
            "platform": "ios"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Get access token from keychain
        if let accessToken = KeychainManager.shared.get(key: KeychainManager.Keys.accessToken) {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("Error registering device token: \(errorMessage)")
            }
            throw URLError(.badServerResponse)
        }

        print("Successfully registered device token with backend")
    }

    // Handle notification received while app is in foreground
    func handleForegroundNotification(notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        print("Received foreground notification: \(userInfo)")

        // Handle different notification types
        if let category = notification.request.content.categoryIdentifier {
            switch category {
            case NotificationCategory.nuggetsReady.rawValue:
                handleNuggetsReadyNotification(userInfo: userInfo)
            case NotificationCategory.streakReminder.rawValue:
                handleStreakReminderNotification(userInfo: userInfo)
            case NotificationCategory.newContent.rawValue:
                handleNewContentNotification(userInfo: userInfo)
            default:
                break
            }
        }
    }

    // Handle notification tapped
    func handleNotificationResponse(response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        print("User tapped notification: \(userInfo)")

        // Handle different notification types
        if let category = response.notification.request.content.categoryIdentifier {
            switch category {
            case NotificationCategory.nuggetsReady.rawValue:
                handleNuggetsReadyNotification(userInfo: userInfo)
            case NotificationCategory.streakReminder.rawValue:
                handleStreakReminderNotification(userInfo: userInfo)
            case NotificationCategory.newContent.rawValue:
                handleNewContentNotification(userInfo: userInfo)
            default:
                break
            }
        }
    }

    // Handle remote notification received
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        print("Received remote notification: \(userInfo)")

        // Extract notification data
        if let aps = userInfo["aps"] as? [String: Any] {
            print("APS payload: \(aps)")
        }

        // Refresh data based on notification type
        if let notificationType = userInfo["type"] as? String {
            switch notificationType {
            case NotificationCategory.nuggetsReady.rawValue:
                // Refresh nuggets list
                do {
                    _ = try await NuggetService.shared.listNuggets()
                    return .newData
                } catch {
                    print("Error refreshing nuggets: \(error)")
                    return .failed
                }
            case NotificationCategory.streakReminder.rawValue, NotificationCategory.newContent.rawValue:
                return .newData
            default:
                return .noData
            }
        }

        return .noData
    }

    // MARK: - Private notification handlers

    private func handleNuggetsReadyNotification(userInfo: [AnyHashable: Any]) {
        // Navigate to inbox or refresh nuggets
        NotificationCenter.default.post(
            name: NSNotification.Name("NuggetsReadyNotification"),
            object: nil,
            userInfo: userInfo as? [String: Any]
        )
    }

    private func handleStreakReminderNotification(userInfo: [AnyHashable: Any]) {
        // Navigate to session start or show reminder
        NotificationCenter.default.post(
            name: NSNotification.Name("StreakReminderNotification"),
            object: nil,
            userInfo: userInfo as? [String: Any]
        )
    }

    private func handleNewContentNotification(userInfo: [AnyHashable: Any]) {
        // Navigate to new content or refresh
        NotificationCenter.default.post(
            name: NSNotification.Name("NewContentNotification"),
            object: nil,
            userInfo: userInfo as? [String: Any]
        )
    }
}
