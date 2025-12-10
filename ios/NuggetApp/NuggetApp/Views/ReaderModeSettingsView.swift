import SwiftUI

struct ReaderModeSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("readerModeByDefault") private var readerModeByDefault = true

    private var isPremiumUser: Bool {
        let tier = authService.currentUser?.subscriptionTier ?? "free"
        return tier == "pro" || tier == "ultimate"
    }

    var body: some View {
        if !isPremiumUser {
            PremiumFeatureGate(
                feature: "Reader Mode",
                description: "Strip away ads, pop-ups, and distractions for a clean reading experience.",
                icon: "doc.plaintext",
                requiredTier: "Pro"
            )
        } else {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "doc.plaintext")
                        .font(.system(size: 50))
                        .foregroundColor(.primary)

                    Text("Reader Mode")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Strip away ads, pop-ups, and distractions for a clean reading experience")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)

                // Settings
                VStack(spacing: 0) {
                        // Enable by default toggle
                        Toggle(isOn: $readerModeByDefault) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Open in Reader Mode")
                                    .font(.body)
                                Text("Automatically open articles in Reader Mode")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .hapticToggle(readerModeByDefault)

                        Divider().padding(.horizontal)

                        // Info section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.secondary)
                                Text("When enabled, links from nuggets will open in Safari's Reader Mode for distraction-free reading.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // How it works section
                VStack(alignment: .leading, spacing: 16) {
                        Text("How it works")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            FeatureExplanationRow(
                                icon: "1.circle.fill",
                                title: "Tap an article link",
                                description: "From any nugget summary"
                            )

                            FeatureExplanationRow(
                                icon: "2.circle.fill",
                                title: "Reader Mode activates",
                                description: "Safari strips away clutter automatically"
                            )

                            FeatureExplanationRow(
                                icon: "3.circle.fill",
                                title: "Read comfortably",
                                description: "Just the content, no distractions"
                            )
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Reader Mode")
        } // end else (premium check)
    }
}

struct FeatureExplanationRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.primary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        ReaderModeSettingsView()
            .environmentObject(AuthService())
    }
}
