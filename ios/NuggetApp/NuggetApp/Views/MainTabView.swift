import SwiftUI

struct MainTabView: View {
    @StateObject private var badgeManager = NuggetBadgeManager.shared
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    @State private var selectedTab = 0
    @State private var showFriends = false
    @State private var showSharedWithMe = false

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
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            InboxView()
                .tabItem {
                    Label("Feed", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(1)

            NuggetsListView()
                .tabItem {
                    Label("Nuggets", systemImage: "sparkles.rectangle.stack.fill")
                }
                .badge(badgeManager.unreadCount > 0 ? badgeManager.unreadCount : 0)
                .tag(2)

            AudioView()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Profile", systemImage: "brain.head.profile.fill")
                }
                .tag(4)
        }
        .onChange(of: selectedTab) { _, _ in
            HapticFeedback.selection()
        }
        .onChange(of: navigationCoordinator.pendingDestination) { _, destination in
            guard let destination = destination else { return }

            switch destination {
            case .home:
                selectedTab = 0
            case .friends:
                selectedTab = 4 // Go to Profile tab first
                // Small delay to let tab switch complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showFriends = true
                }
            case .sharedWithMe:
                selectedTab = 4 // Go to Profile tab first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showSharedWithMe = true
                }
            case .nugget:
                selectedTab = 2 // Go to Nuggets tab
            }

            // Clear the destination after handling
            navigationCoordinator.clearDestination()
        }
        .sheet(isPresented: $showFriends) {
            FriendsView()
        }
        .sheet(isPresented: $showSharedWithMe) {
            SharedWithMeView()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
}
