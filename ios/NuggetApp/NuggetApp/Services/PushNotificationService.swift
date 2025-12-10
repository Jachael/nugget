import Foundation
import UserNotifications
import UIKit

enum NotificationCategory: String {
    case nuggetsReady = "NUGGETS_READY"
    case streakReminder = "STREAK_REMINDER"
    case newContent = "NEW_CONTENT"
}

// Deep link destinations for notification navigation
enum DeepLinkDestination: Equatable {
    case home
    case friends
    case sharedWithMe
    case nugget(String) // nuggetId
}

// Observable object for navigation state
class NavigationCoordinator: ObservableObject {
    static let shared = NavigationCoordinator()

    @Published var pendingDestination: DeepLinkDestination?

    private init() {}

    func navigate(to destination: DeepLinkDestination) {
        DispatchQueue.main.async {
            self.pendingDestination = destination
        }
    }

    func clearDestination() {
        pendingDestination = nil
    }
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

        // Check current authorization status first
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized {
            print("Notification permission already granted")
            return true
        }

        // Request authorization if not already granted
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
        guard let url = URL(string: "\(APIConfig.baseURL)/device/register") else {
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
        if let accessToken = KeychainManager.shared.getToken() {
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
        let category = notification.request.content.categoryIdentifier
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

    // Handle notification tapped
    func handleNotificationResponse(response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        print("User tapped notification: \(userInfo)")

        // Extract the custom type from userInfo (sent from backend)
        if let notificationType = userInfo["type"] as? String {
            switch notificationType {
            case "FRIEND_REQUEST", "FRIEND_REQUEST_ACCEPTED":
                NavigationCoordinator.shared.navigate(to: .friends)
                return
            case "FRIEND_SHARE":
                NavigationCoordinator.shared.navigate(to: .sharedWithMe)
                return
            case "NUGGETS_READY":
                NavigationCoordinator.shared.navigate(to: .home)
                return
            default:
                break
            }
        }

        // Fallback to category-based handling
        let category = response.notification.request.content.categoryIdentifier
        switch category {
        case NotificationCategory.nuggetsReady.rawValue:
            NavigationCoordinator.shared.navigate(to: .home)
        case NotificationCategory.streakReminder.rawValue:
            NavigationCoordinator.shared.navigate(to: .home)
        case NotificationCategory.newContent.rawValue:
            NavigationCoordinator.shared.navigate(to: .home)
        default:
            break
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
