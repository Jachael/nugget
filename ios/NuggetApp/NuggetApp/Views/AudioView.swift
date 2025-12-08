import SwiftUI

struct AudioView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showSubscription = false

    private var isPremium: Bool {
        let tier = authService.currentUser?.subscriptionTier ?? "free"
        return tier == "pro" || tier == "ultimate"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                // Main feature card
                VStack(spacing: 20) {
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("Audio Nuggets")
                        .font(.title.bold())

                    Text("Listen to your nuggets on the go")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    // Features list
                    VStack(alignment: .leading, spacing: 12) {
                        AudioFeatureRow(icon: "headphones", text: "Convert nuggets to audio")
                        AudioFeatureRow(icon: "car.fill", text: "Listen while commuting")
                        AudioFeatureRow(icon: "brain.head.profile", text: "Retain more through audio learning", usePalette: true)
                        AudioFeatureRow(icon: "clock.fill", text: "Save reading time")
                    }
                    .padding(.vertical, 8)

                    // Premium badge or coming soon
                    if !isPremium {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundColor(.goldAccent)
                            Text("Premium Feature")
                                .font(.caption.bold())
                                .foregroundColor(.goldAccent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.goldAccent.opacity(0.15))
                        .cornerRadius(16)
                    }

                    Text("Coming Soon")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(32)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal)

                // Upgrade prompt for free users
                if !isPremium {
                    VStack(spacing: 16) {
                        Text("Get early access when it launches")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button {
                            showSubscription = true
                        } label: {
                            HStack(spacing: 8) {
                                Text(SparkSymbol.spark)
                                    .font(.caption)
                                Text("Upgrade to Premium")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(GlassProminentButtonStyle())
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()
            }
            .navigationTitle("Audio")
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
        }
    }
}

struct AudioFeatureRow: View {
    let icon: String
    let text: String
    var usePalette: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if usePalette {
                    Image(systemName: icon)
                        .font(.body)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.secondary, .yellow)
                        .frame(width: 24)
                } else {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                }
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    AudioView()
}
