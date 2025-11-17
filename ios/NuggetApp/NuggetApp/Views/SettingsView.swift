import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let user = authService.currentUser {
                        HStack {
                            Text("User ID")
                            Spacer()
                            Text(user.userId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Streak")
                            Spacer()
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text("\(user.streak)")
                            }
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("API")
                        Spacer()
                        Text("api.nugget.jasontesting.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        authService.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
