import SwiftUI

@main
struct NuggetApp: App {
    @StateObject private var authService = AuthService()
    @State private var preferences: UserPreferences?
    @State private var isLoadingPreferences = true
    @State private var showSplash = true
    @State private var dataLoaded = false
    @AppStorage("colorScheme") private var colorScheme: String = "system"

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView()
                        .task {
                            // Start loading data immediately in parallel
                            async let minimumAnimationTime: () = Task.sleep(nanoseconds: 2_200_000_000)
                            async let dataLoad: () = loadAllDataAsync()

                            // Wait for both animation and data loading to complete
                            _ = try? await (minimumAnimationTime, dataLoad)

                            // Only hide splash when both animation is done AND data is loaded
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSplash = false
                            }
                        }
                } else if !authService.isAuthenticated {
                    LoginView()
                        .environmentObject(authService)
                } else if isLoadingPreferences {
                    // Don't show splash again, just show a blank screen briefly
                    Color.clear
                        .task {
                            await loadPreferencesAsync()
                        }
                } else if let prefs = preferences, !prefs.onboardingCompleted {
                    OnboardingView(isOnboardingComplete: .init(
                        get: { prefs.onboardingCompleted },
                        set: { newValue in
                            if newValue {
                                Task {
                                    await loadPreferencesAsync()
                                }
                            }
                        }
                    ))
                } else {
                    MainTabView()
                        .environmentObject(authService)
                }
            }
            .onChange(of: authService.isAuthenticated) { oldValue, newValue in
                if newValue {
                    Task {
                        await loadPreferencesAsync()
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
    private func loadPreferencesAsync() async {
        do {
            let prefs = try await PreferencesService.shared.getPreferences()
            preferences = prefs
            isLoadingPreferences = false
        } catch {
            // If preferences don't exist or there's an error, show onboarding
            preferences = UserPreferences.default
            isLoadingPreferences = false
            print("Error loading preferences: \(error)")
        }
    }

    @MainActor
    private func loadAllDataAsync() async {
        // Only load if authenticated
        guard authService.isAuthenticated else {
            dataLoaded = true
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
                    }
                } catch {
                    await MainActor.run {
                        self.preferences = UserPreferences.default
                        self.isLoadingPreferences = false
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
        }

        dataLoaded = true
    }
}
