import SwiftUI

@main
struct NuggetApp: App {
    @StateObject private var authService = AuthService()
    @State private var preferences: UserPreferences?
    @State private var isLoadingPreferences = true
    @State private var showTutorial = false
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

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
                } else {
                    MainTabView()
                        .environmentObject(authService)
                        .sheet(isPresented: $showTutorial) {
                            TutorialView()
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
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.preferences = UserPreferences.default
                        self.isLoadingPreferences = false
                        // Show tutorial if preferences don't exist
                        if !self.hasSeenTutorial {
                            self.showTutorial = true
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
        }
    }
}
