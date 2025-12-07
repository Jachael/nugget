import SwiftUI

struct MainTabView: View {
    init() {
        // Customize tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // Make tab bar slightly more compact
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.label
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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
                    Label("Nuggets", systemImage: "square.stack.3d.up.fill")
                }

            AudioView()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }

            SettingsView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
        .tint(.primary)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
}
