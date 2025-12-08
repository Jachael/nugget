import SwiftUI

struct MainTabView: View {
    @StateObject private var badgeManager = NuggetBadgeManager.shared

    init() {
        // Customize tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // Configure icon colors
        // Inactive tabs: grey (secondary)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        // Active tabs: black (label)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.label

        // Configure title text
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.label
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Set tab bar tint color directly to avoid cascading to child views
        UITabBar.appearance().tintColor = UIColor.label
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            InboxView()
                .tabItem {
                    Label("Feed", systemImage: "list.bullet.rectangle.fill")
                }

            NuggetsListView()
                .tabItem {
                    Label("Nuggets", systemImage: "sparkles.rectangle.stack.fill")
                }
                .badge(badgeManager.unreadCount > 0 ? badgeManager.unreadCount : 0)

            AudioView()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }

            SettingsView()
                .tabItem {
                    Label("Profile", systemImage: "brain.head.profile.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
}
