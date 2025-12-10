import SwiftUI

struct OfflineNuggetsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var offlineService = OfflineStorageService.shared

    @State private var cachedNuggets: [OfflineNugget] = []
    @State private var isLoading = true
    @State private var settings: OfflineSettings = .default
    @State private var showClearConfirmation = false

    private var isUltimateUser: Bool {
        authService.currentUser?.subscriptionTier == "ultimate"
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            if !isUltimateUser {
                upgradeRequiredView
            } else {
                offlineContentView
            }
        }
        .navigationBarTitle("Offline Nuggets", displayMode: .inline)
        .onAppear {
            loadData()
        }
        .alert("Clear All Cached Nuggets?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                offlineService.clearAllCache()
                cachedNuggets = []
            }
        } message: {
            Text("This will remove all \(cachedNuggets.count) cached nuggets from your device. This cannot be undone.")
        }
    }

    // MARK: - Views

    private var upgradeRequiredView: some View {
        PremiumFeatureGate(
            feature: "Offline Mode",
            description: "Save nuggets to your device for reading without an internet connection.",
            icon: "arrow.down.circle.fill",
            requiredTier: "Ultimate"
        )
    }

    private var offlineContentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Storage Stats Card
                storageStatsCard

                // Settings Card
                settingsCard

                // Cached Nuggets
                if cachedNuggets.isEmpty {
                    emptyStateCard
                } else {
                    cachedNuggetsSection
                }
            }
            .padding()
        }
    }

    private var storageStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundColor(.purple)
                Text("Storage")
                    .font(.headline)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(offlineService.cachedNuggetCount)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Cached Nuggets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(offlineService.storageUsedFormatted)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("of \(settings.storageLimitMB) MB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(storageProgressColor)
                        .frame(width: geometry.size.width * storageProgress, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var storageProgress: CGFloat {
        min(CGFloat(offlineService.storageUsedMB) / CGFloat(settings.storageLimitMB), 1.0)
    }

    private var storageProgressColor: Color {
        if storageProgress > 0.9 {
            return .red
        } else if storageProgress > 0.7 {
            return .orange
        }
        return .purple
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape")
                    .foregroundColor(.purple)
                Text("Settings")
                    .font(.headline)
            }

            Toggle("Enable Offline Mode", isOn: $settings.isEnabled)
                .onChange(of: settings.isEnabled) { _, _ in
                    offlineService.saveSettings(settings)
                }

            Toggle("Auto-cache Completed Nuggets", isOn: $settings.autoCache)
                .onChange(of: settings.autoCache) { _, _ in
                    offlineService.saveSettings(settings)
                }

            HStack {
                Text("Storage Limit")
                Spacer()
                Picker("Limit", selection: $settings.storageLimitMB) {
                    Text("50 MB").tag(50)
                    Text("100 MB").tag(100)
                    Text("200 MB").tag(200)
                    Text("500 MB").tag(500)
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: settings.storageLimitMB) { _, _ in
                    offlineService.saveSettings(settings)
                    offlineService.cleanupOldCache(limitMB: settings.storageLimitMB)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Cached Nuggets")
                .font(.headline)

            Text("Completed nuggets will be automatically cached for offline reading when enabled.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var cachedNuggetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cached Nuggets")
                    .font(.headline)

                Spacer()

                Button(action: { showClearConfirmation = true }) {
                    Text("Clear All")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            ForEach(cachedNuggets, id: \.nuggetId) { nugget in
                CachedNuggetRow(
                    nugget: nugget,
                    onDelete: {
                        offlineService.removeCachedNugget(id: nugget.nuggetId)
                        cachedNuggets.removeAll { $0.nuggetId == nugget.nuggetId }
                    }
                )
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        settings = offlineService.getSettings()
        cachedNuggets = offlineService.getAllCachedNuggets()
        isLoading = false
    }
}

// MARK: - Cached Nugget Row

struct CachedNuggetRow: View {
    let nugget: OfflineNugget
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(nugget.title ?? "Untitled")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if let category = nugget.category {
                    Text(category.capitalized)
                        .font(.caption)
                        .foregroundColor(.purple)
                }

                Text("Cached \(formatDate(nugget.cachedAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct OfflineNuggetsView_Previews: PreviewProvider {
    static var previews: some View {
        OfflineNuggetsView()
            .environmentObject(AuthService())
    }
}
