import SwiftUI

struct MainTabView: View {
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

            AudioView()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }

            SettingsView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
}
