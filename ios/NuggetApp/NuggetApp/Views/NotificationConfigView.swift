import SwiftUI

// MARK: - Settings Service

struct UserSettingsResponse: Codable {
    let settings: UserSettingsData
    let tier: String?
    let hasAdvancedNotifications: Bool?
}

struct UserSettingsData: Codable {
    var notificationsEnabled: Bool?
    var notifyOnAllNuggets: Bool?
    var notifyCategories: [String]?
    var notifyFeeds: [String]?
    var notifyDigests: [String]?
    var readerModeEnabled: Bool?
    var offlineEnabled: Bool?
}

struct UpdateSettingsRequest: Codable {
    let notificationsEnabled: Bool?
    let notifyOnAllNuggets: Bool?
    let notifyCategories: [String]?
    let notifyFeeds: [String]?
    let notifyDigests: [String]?
    let readerModeEnabled: Bool?
    let offlineEnabled: Bool?
}

struct UpdateSettingsResponse: Codable {
    let message: String
    let settings: UserSettingsData
    let tier: String?
    let hasAdvancedNotifications: Bool?
}

final class SettingsService {
    static let shared = SettingsService()

    private init() {}

    func getSettings() async throws -> UserSettingsResponse {
        return try await APIClient.shared.send(
            path: "/settings",
            method: "GET",
            requiresAuth: true,
            responseType: UserSettingsResponse.self
        )
    }

    func updateSettings(_ settings: UpdateSettingsRequest) async throws -> UpdateSettingsResponse {
        return try await APIClient.shared.send(
            path: "/settings",
            method: "PUT",
            body: settings,
            requiresAuth: true,
            responseType: UpdateSettingsResponse.self
        )
    }
}

// MARK: - Notification Configuration View

struct NotificationConfigView: View {
    @EnvironmentObject var authService: AuthService

    @State private var isLoading = true
    @State private var settings = UserSettingsData()
    @State private var hasAdvancedNotifications = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    // Available options (would be fetched from API in production)
    @State private var availableCategories: [String] = [
        "technology", "sport", "finance", "career", "health",
        "science", "business", "entertainment", "politics", "education"
    ]
    @State private var availableFeeds: [CatalogFeed] = []
    @State private var availableDigests: [CustomDigest] = []

    private var isUltimateUser: Bool {
        authService.currentUser?.subscriptionTier == "ultimate"
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading settings...")
            } else {
                Form {
                    // Basic Notifications Section
                    Section(header: Text("Notifications")) {
                        Toggle("Enable Notifications", isOn: Binding(
                            get: { settings.notificationsEnabled ?? true },
                            set: {
                                settings.notificationsEnabled = $0
                                saveSettings()
                            }
                        ))
                    }

                }
            }
        }
        .navigationBarTitle("Notifications", displayMode: .inline)
        .onAppear {
            loadSettings()
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Advanced Notification Section

    private var advancedNotificationSection: some View {
        Group {
            Section(header: Text("Notification Filter")) {
                Toggle("Notify for All Nuggets", isOn: Binding(
                    get: { settings.notifyOnAllNuggets ?? true },
                    set: { settings.notifyOnAllNuggets = $0 }
                ))

                if !(settings.notifyOnAllNuggets ?? true) {
                    Text("When disabled, you'll only be notified for selected categories, feeds, or digests below.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !(settings.notifyOnAllNuggets ?? true) {
                // Category Filter
                Section(header: Text("Notify for Categories")) {
                    ForEach(availableCategories, id: \.self) { category in
                        CategoryToggleRow(
                            category: category,
                            isSelected: settings.notifyCategories?.contains(category) ?? false,
                            onToggle: { isSelected in
                                var categories = settings.notifyCategories ?? []
                                if isSelected {
                                    if !categories.contains(category) && categories.count < 10 {
                                        categories.append(category)
                                    }
                                } else {
                                    categories.removeAll { $0 == category }
                                }
                                settings.notifyCategories = categories
                            }
                        )
                    }
                }

                // Feed Filter
                if !availableFeeds.isEmpty {
                    Section(header: Text("Notify for Feeds")) {
                        ForEach(availableFeeds.prefix(10)) { feed in
                            FeedToggleRow(
                                feed: feed,
                                isSelected: settings.notifyFeeds?.contains(feed.id) ?? false,
                                onToggle: { isSelected in
                                    var feeds = settings.notifyFeeds ?? []
                                    if isSelected {
                                        if !feeds.contains(feed.id) && feeds.count < 10 {
                                            feeds.append(feed.id)
                                        }
                                    } else {
                                        feeds.removeAll { $0 == feed.id }
                                    }
                                    settings.notifyFeeds = feeds
                                }
                            )
                        }
                    }
                }

                // Digest Filter
                if !availableDigests.isEmpty {
                    Section(header: Text("Notify for Digests")) {
                        ForEach(availableDigests) { digest in
                            DigestToggleRow(
                                digest: digest,
                                isSelected: settings.notifyDigests?.contains(digest.digestId) ?? false,
                                onToggle: { isSelected in
                                    var digests = settings.notifyDigests ?? []
                                    if isSelected {
                                        if !digests.contains(digest.digestId) && digests.count < 10 {
                                            digests.append(digest.digestId)
                                        }
                                    } else {
                                        digests.removeAll { $0 == digest.digestId }
                                    }
                                    settings.notifyDigests = digests
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Upgrade Prompt Section

    private var upgradePromptSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.purple)
                    Text("Ultimate Feature")
                        .font(.headline)
                }

                Text("Upgrade to Ultimate to customize which categories, feeds, and digests trigger notifications.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: {
                    // TODO: Navigate to subscription flow
                }) {
                    Text("Learn More")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - API Calls

    private func loadSettings() {
        isLoading = true
        Task {
            do {
                async let settingsResponse = SettingsService.shared.getSettings()
                async let feedsResponse = FeedService.shared.getFeeds()
                async let digestsResponse = FeedService.shared.getDigests()

                let (settingsResult, feedsResult, digestsResult) = try await (settingsResponse, feedsResponse, digestsResponse)

                await MainActor.run {
                    self.settings = settingsResult.settings
                    self.hasAdvancedNotifications = settingsResult.hasAdvancedNotifications ?? false
                    self.availableFeeds = feedsResult.catalog.filter { $0.isSubscribed }
                    self.availableDigests = digestsResult.digests
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }

    private func saveSettings() {
        isSaving = true
        Task {
            do {
                let request = UpdateSettingsRequest(
                    notificationsEnabled: settings.notificationsEnabled,
                    notifyOnAllNuggets: settings.notifyOnAllNuggets,
                    notifyCategories: settings.notifyCategories,
                    notifyFeeds: settings.notifyFeeds,
                    notifyDigests: settings.notifyDigests,
                    readerModeEnabled: settings.readerModeEnabled,
                    offlineEnabled: settings.offlineEnabled
                )

                _ = try await SettingsService.shared.updateSettings(request)

                await MainActor.run {
                    isSaving = false
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Toggle Rows

struct CategoryToggleRow: View {
    let category: String
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button(action: { onToggle(!isSelected) }) {
            HStack {
                Text(category.capitalized)
                    .foregroundColor(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.purple)
                }
            }
        }
    }
}

struct FeedToggleRow: View {
    let feed: CatalogFeed
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button(action: { onToggle(!isSelected) }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(feed.name)
                        .foregroundColor(.primary)
                    Text(feed.category.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.purple)
                }
            }
        }
    }
}

struct DigestToggleRow: View {
    let digest: CustomDigest
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button(action: { onToggle(!isSelected) }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(digest.name)
                        .foregroundColor(.primary)
                    Text("\(digest.feedIds.count) feeds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.purple)
                }
            }
        }
    }
}

struct NotificationConfigView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationConfigView()
            .environmentObject(AuthService())
    }
}
