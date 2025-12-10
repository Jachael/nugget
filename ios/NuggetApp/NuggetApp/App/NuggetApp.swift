import SwiftUI
import UserNotifications

// AppDelegate for handling push notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Reset upgrade tile dismissed state on app launch
        // This allows the tile to reappear on next app open if user dismissed it
        UserDefaults.standard.set(false, forKey: "upgradeTileDismissed")

        return true
    }

    // Called when APNs successfully registers the device
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")

        // Send token to backend
        Task {
            do {
                try await PushNotificationService.shared.sendTokenToBackend(deviceToken: token)
            } catch {
                print("Error sending device token to backend: \(error)")
            }
        }
    }

    // Called when APNs fails to register the device
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    // Handle remote notification received
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        return await PushNotificationService.shared.handleRemoteNotification(userInfo: userInfo)
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        PushNotificationService.shared.handleForegroundNotification(notification: notification)
        return [.banner, .sound, .badge]
    }

    // Handle notification response (user tapped on notification)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        PushNotificationService.shared.handleNotificationResponse(response: response)
    }
}

@main
struct NuggetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @State private var preferences: UserPreferences?
    @State private var isLoadingPreferences = true
    @State private var showTutorial = false
    @State private var showBetaWelcome = false
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if !authService.isAuthenticated {
                    LoginView()
                        .environmentObject(authService)
                } else if isLoadingPreferences {
                    Color.clear
                        .task {
                            await loadPreferencesAndDataAsync()
                        }
                } else if showBetaWelcome {
                    BetaWelcomeView(userName: authService.currentUser?.firstName ?? "Beta Tester") {
                        TestFlightHelper.markBetaWelcomeSeen()
                        withAnimation {
                            showBetaWelcome = false
                        }
                    }
                } else {
                    MainTabView()
                        .environmentObject(authService)
                        .sheet(isPresented: $showTutorial) {
                            TutorialView()
                                .onDisappear {
                                    // After tutorial dismisses, check if we should show beta welcome
                                    if TestFlightHelper.shouldShowBetaWelcome {
                                        showBetaWelcome = true
                                    }
                                }
                        }
                }
            }
            .onChange(of: authService.isAuthenticated) { oldValue, newValue in
                if newValue {
                    Task {
                        await loadPreferencesAndDataAsync()
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Process pending shared nuggets when app becomes active
                if newPhase == .active && authService.isAuthenticated {
                    // Clear badge when app becomes active
                    UNUserNotificationCenter.current().setBadgeCount(0)

                    Task {
                        do {
                            let processed = try await NuggetService.shared.processPendingSharedNuggets()
                            if processed {
                                // Notify views to refresh
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshNuggets"), object: nil)
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
                            }
                        } catch {
                            print("Error processing pending nuggets on active: \(error)")
                        }
                    }
                }
            }
            .preferredColorScheme(getColorScheme())
        }
    }

    private func getColorScheme() -> ColorScheme? {
        switch colorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    @MainActor
    private func loadPreferencesAndDataAsync() async {
        // Only load if authenticated
        guard authService.isAuthenticated else {
            isLoadingPreferences = false
            return
        }

        // Load all necessary data in parallel
        await withTaskGroup(of: Void.self) { group in
            // Load preferences
            group.addTask {
                do {
                    let prefs = try await PreferencesService.shared.getPreferences()
                    await MainActor.run {
                        self.preferences = prefs
                        self.isLoadingPreferences = false
                        // Show tutorial if user hasn't seen it yet
                        if !self.hasSeenTutorial {
                            self.showTutorial = true
                        } else if TestFlightHelper.shouldShowBetaWelcome {
                            // Show beta welcome for returning TestFlight users
                            self.showBetaWelcome = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.preferences = UserPreferences.default
                        self.isLoadingPreferences = false
                        // Show tutorial if preferences don't exist
                        if !self.hasSeenTutorial {
                            self.showTutorial = true
                        } else if TestFlightHelper.shouldShowBetaWelcome {
                            // Show beta welcome for returning TestFlight users
                            self.showBetaWelcome = true
                        }
                    }
                    print("Error loading preferences: \(error)")
                }
            }

            // Pre-load nuggets list for faster initial display
            group.addTask {
                do {
                    _ = try await NuggetService.shared.listNuggets()
                    // The data is now cached and will load instantly when HomeView appears
                } catch {
                    print("Error pre-loading nuggets: \(error)")
                }
            }

            // Process any pending nuggets from Share Extension
            group.addTask {
                do {
                    let processed = try await NuggetService.shared.processPendingSharedNuggets()
                    if processed {
                        print("Processed pending nuggets from share extension")
                        // Refresh nuggets list to show newly added items
                        _ = try? await NuggetService.shared.listNuggets()
                    }
                } catch {
                    print("Error processing pending nuggets: \(error)")
                }
            }

            // Request notification permissions and register for remote notifications
            group.addTask {
                do {
                    let granted = try await PushNotificationService.shared.requestAuthorization()
                    if granted {
                        await MainActor.run {
                            PushNotificationService.shared.registerForRemoteNotifications()
                        }
                    }
                } catch {
                    print("Error requesting notification permissions: \(error)")
                }
            }
        }
    }
}
