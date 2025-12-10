import SwiftUI

struct RSSFeedsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var feeds: [CatalogFeed] = []
    @State private var subscriptions: [FeedSubscription] = []
    @State private var customFeeds: [CustomRSSFeed] = []
    @State private var isLoading = true
    @State private var isFetching = false
    @State private var error: String?
    @State private var successMessage: String?
    @State private var showingUpgradePrompt = false
    @State private var selectedCategory: String?
    @State private var feedToSubscribe: CatalogFeed?
    @State private var showFeedConfigSheet = false
    @State private var showAddCustomFeed = false

    private var isPremium: Bool {
        let tier = authService.currentUser?.subscriptionTier ?? "free"
        return tier == "pro" || tier == "ultimate"
    }

    private var isUltimate: Bool {
        authService.currentUser?.subscriptionTier == "ultimate"
    }

    private var categories: [String] {
        let allCategories = Set(feeds.map { $0.category })
        return Array(allCategories).sorted()
    }

    private var filteredFeeds: [CatalogFeed] {
        if let category = selectedCategory {
            return feeds.filter { $0.category == category }
        }
        return feeds
    }

    var body: some View {
        NavigationStack {
            if !isPremium {
                // Premium gate for free users
                PremiumFeatureGate(
                    feature: "RSS Feeds",
                    description: "Subscribe to quality news sources and get AI-powered daily recaps delivered to you.",
                    icon: "dot.radiowaves.up.forward",
                    requiredTier: "Pro"
                )
            } else {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header section
                    Text("Subscribe to quality news sources and get AI-powered daily recaps")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Status messages
                    if let successMessage = successMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.primary)
                            Text(successMessage)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    if let error = error {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Fetch content button
                    if !subscriptions.isEmpty {
                        Button(action: {
                            Task {
                                await fetchFeedContent()
                            }
                        }) {
                            HStack {
                                if isFetching {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(isFetching ? "Fetching feeds..." : "Fetch Latest Content")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlassProminentButtonStyle())
                        .disabled(isFetching)
                        .padding(.horizontal)
                    }

                    // Category filter
                    if !categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                CategoryFilterChip(
                                    title: "All",
                                    isSelected: selectedCategory == nil
                                ) {
                                    selectedCategory = nil
                                }

                                ForEach(categories, id: \.self) { category in
                                    CategoryFilterChip(
                                        title: category.capitalized,
                                        isSelected: selectedCategory == category
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Custom Feeds Section (Ultimate Only)
                    if isUltimate {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Your Custom Feeds")
                                    .font(.headline)
                                Text("ULTIMATE")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.8))
                                    .cornerRadius(4)
                                Spacer()
                                Button {
                                    showAddCustomFeed = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal)

                            if customFeeds.isEmpty {
                                HStack {
                                    Image(systemName: "globe")
                                        .foregroundColor(.secondary)
                                    Text("Add your own RSS feeds")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(in: .rect(cornerRadius: 12))
                                .padding(.horizontal)
                            } else {
                                ForEach(customFeeds) { feed in
                                    CustomFeedRow(feed: feed) {
                                        deleteCustomFeed(feed)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.bottom, 8)

                        Divider()
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                    }

                    // Feed list
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Curated Feeds")
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVStack(spacing: 12) {
                                ForEach(filteredFeeds) { feed in
                                    FeedRow(
                                        feed: feed,
                                        isPremium: isPremium,
                                        isUltimate: isUltimate,
                                        onToggle: {
                                            handleFeedToggle(feed: feed)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .refreshable {
                await loadFeeds()
            }
        }
        .navigationTitle("RSS Feeds")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.medium)
            }
        }
        .task {
            await loadFeeds()
        }
        .alert("Upgrade to Pro", isPresented: $showingUpgradePrompt) {
            Button("Cancel", role: .cancel) {}
            Button("Upgrade") {
                // TODO: Navigate to subscription screen
            }
        } message: {
            Text("This feed requires a Pro subscription. Upgrade to access premium content sources.")
        }
        .sheet(isPresented: $showFeedConfigSheet) {
            if let feed = feedToSubscribe {
                FeedConfigSheet(
                    feed: feed,
                    onSubscribe: { config in
                        Task {
                            await subscribeWithConfig(feed: feed, config: config)
                        }
                    },
                    onCancel: {
                        feedToSubscribe = nil
                        showFeedConfigSheet = false
                    }
                )
            }
        }
        .sheet(isPresented: $showAddCustomFeed) {
            AddCustomFeedView { newFeed in
                customFeeds.append(newFeed)
                showAddCustomFeed = false
                successMessage = "Added \(newFeed.name)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    successMessage = nil
                }
            }
        }
            } // end else (premium check)
        } // end NavigationStack
    }

    private func handleFeedToggle(feed: CatalogFeed) {
        // Check premium requirement
        if feed.isPremium && !isPremium && !feed.isSubscribed {
            showingUpgradePrompt = true
            return
        }

        if feed.isSubscribed {
            // Unsubscribe directly
            Task {
                await toggleSubscription(feed: feed)
            }
        } else if isUltimate {
            // Show config sheet for Ultimate users when subscribing
            feedToSubscribe = feed
            showFeedConfigSheet = true
        } else {
            // Subscribe directly for non-Ultimate users
            Task {
                await toggleSubscription(feed: feed)
            }
        }
    }

    private func subscribeWithConfig(feed: CatalogFeed, config: FeedConfig) async {
        error = nil
        successMessage = nil
        showFeedConfigSheet = false
        feedToSubscribe = nil

        do {
            // Subscribe to the feed
            let response = try await FeedService.shared.subscribeFeed(
                rssFeedId: feed.id,
                subscribe: true
            )

            // TODO: Save feed config to backend when per-feed settings are implemented
            // For now, we just subscribe and store config locally
            print("Feed subscribed with config: autoFetch=\(config.autoFetch)")

            successMessage = response.message

            // Refresh feeds
            await loadFeeds()

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                successMessage = nil
            }
        } catch {
            self.error = "Failed to subscribe: \(error.localizedDescription)"
        }
    }

    private func loadFeeds() async {
        isLoading = true
        error = nil

        do {
            let response = try await FeedService.shared.getFeeds()
            feeds = response.catalog
            subscriptions = response.subscriptions

            // Load custom feeds for Ultimate users
            if isUltimate {
                do {
                    let customResponse = try await FeedService.shared.getCustomFeeds()
                    customFeeds = customResponse.feeds
                } catch {
                    // Custom feeds are optional - don't fail the whole load
                    print("Failed to load custom feeds: \(error)")
                }
            }

            isLoading = false
        } catch {
            self.error = "Failed to load feeds: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func deleteCustomFeed(_ feed: CustomRSSFeed) {
        Task {
            do {
                let _ = try await FeedService.shared.deleteCustomFeed(feedId: feed.feedId)
                await MainActor.run {
                    withAnimation {
                        customFeeds.removeAll { $0.id == feed.id }
                    }
                    HapticFeedback.selection()
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to remove feed"
                }
            }
        }
    }

    private func toggleSubscription(feed: CatalogFeed) async {
        // Check premium requirement
        if feed.isPremium && !isPremium && !feed.isSubscribed {
            showingUpgradePrompt = true
            return
        }

        error = nil
        successMessage = nil

        do {
            let response = try await FeedService.shared.subscribeFeed(
                rssFeedId: feed.id,
                subscribe: !feed.isSubscribed
            )

            successMessage = response.message

            // Refresh feeds to update subscription status
            await loadFeeds()

            // Clear success message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                successMessage = nil
            }
        } catch {
            self.error = "Failed to update subscription: \(error.localizedDescription)"
        }
    }

    private func fetchFeedContent() async {
        isFetching = true
        error = nil
        successMessage = nil

        do {
            let response = try await FeedService.shared.fetchFeedContent()
            successMessage = response.message

            // Clear success message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                successMessage = nil
            }

            isFetching = false
        } catch {
            self.error = "Failed to fetch feed content: \(error.localizedDescription)"
            isFetching = false
        }
    }
}

// MARK: - Feed Row
struct FeedRow: View {
    let feed: CatalogFeed
    let isPremium: Bool
    let isUltimate: Bool
    let onToggle: () -> Void
    @State private var isToggling = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(feed.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(feed.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(feed.category.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isToggling {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: {
                    isToggling = true
                    HapticFeedback.light()
                    onToggle()
                    // Reset after a delay since parent will reload
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isToggling = false
                    }
                }) {
                    HStack(spacing: 8) {
                        // Show gear icon for Ultimate users when not subscribed
                        if isUltimate && !feed.isSubscribed {
                            Image(systemName: "gearshape")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: feed.isSubscribed ? "checkmark.circle.fill" : "plus.circle")
                            .font(.title2)
                            .foregroundColor(feed.isSubscribed ? .primary : .secondary)
                    }
                }
                .disabled(feed.isPremium && !isPremium && !feed.isSubscribed)
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 14))
    }
}

// MARK: - Feed Config
struct FeedConfig {
    var autoFetch: Bool = true
    var fetchFrequency: FetchFrequency = .withSchedule

    enum FetchFrequency: String, CaseIterable, Identifiable {
        case withSchedule = "With auto-processing schedule"
        case hourly = "Every hour"
        case every3Hours = "Every 3 hours"
        case every6Hours = "Every 6 hours"
        case daily = "Once daily"

        var id: String { rawValue }
    }
}

// MARK: - Feed Config Sheet
struct FeedConfigSheet: View {
    let feed: CatalogFeed
    let onSubscribe: (FeedConfig) -> Void
    let onCancel: () -> Void

    @State private var config = FeedConfig()

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(feed.name)
                            .font(.headline)
                        Text(feed.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(feed.category.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Auto-Fetch Settings")) {
                    Toggle("Auto-fetch new content", isOn: $config.autoFetch)

                    if config.autoFetch {
                        Picker("Fetch frequency", selection: $config.fetchFrequency) {
                            ForEach(FeedConfig.FetchFrequency.allCases) { frequency in
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                    }
                }

                Section {
                    Text("These settings can be changed later in feed settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Configure Feed")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                },
                trailing: Button("Subscribe") {
                    onSubscribe(config)
                }
                .fontWeight(.semibold)
            )
        }
    }
}

// MARK: - Category Filter Chip
struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            action()
        }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect(isSelected ? .regular.interactive() : .regular, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Feed Row
struct CustomFeedRow: View {
    let feed: CustomRSSFeed
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(feed.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if !feed.isValid {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }

                if let description = feed.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(feed.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundColor(.red.opacity(0.8))
            }
            .confirmationDialog("Remove Feed", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Remove \(feed.name)", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will stop fetching content from this feed.")
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 14))
    }
}

// MARK: - Add Custom Feed View
struct AddCustomFeedView: View {
    let onAdd: (CustomRSSFeed) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var urlInput = ""
    @State private var nameOverride = ""
    @State private var category = "general"
    @State private var isValidating = false
    @State private var isAdding = false
    @State private var validationResult: ValidateFeedResponse?
    @State private var error: String?

    private let categories = ["general", "technology", "news", "business", "science", "health", "entertainment", "sports"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("RSS Feed URL")) {
                    TextField("https://example.com/feed.xml", text: $urlInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button {
                        validateFeed()
                    } label: {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle")
                            }
                            Text(isValidating ? "Validating..." : "Validate Feed")
                        }
                    }
                    .disabled(urlInput.isEmpty || isValidating)
                }

                if let result = validationResult {
                    Section(header: Text("Feed Preview")) {
                        if result.isValid {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Valid RSS Feed")
                                        .fontWeight(.medium)
                                }

                                if let title = result.title {
                                    Text(title)
                                        .font(.headline)
                                }

                                if let description = result.description {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                if let count = result.articleCount, count > 0 {
                                    Text("\(count) articles available")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(result.error ?? "Invalid RSS feed")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

                if validationResult?.isValid == true {
                    Section(header: Text("Customize (Optional)")) {
                        TextField("Custom name", text: $nameOverride)

                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { cat in
                                Text(cat.capitalized).tag(cat)
                            }
                        }
                    }
                }

                if let error = error {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Add Custom Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addFeed()
                    } label: {
                        if isAdding {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(validationResult?.isValid != true || isAdding)
                }
            }
        }
    }

    private func validateFeed() {
        isValidating = true
        error = nil
        validationResult = nil

        Task {
            do {
                let result = try await FeedService.shared.validateFeedUrl(urlInput)
                await MainActor.run {
                    validationResult = result
                    isValidating = false
                    if result.isValid, let title = result.title {
                        nameOverride = title
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to validate: \(error.localizedDescription)"
                    isValidating = false
                }
            }
        }
    }

    private func addFeed() {
        isAdding = true
        error = nil

        Task {
            do {
                let response = try await FeedService.shared.addCustomFeed(
                    url: urlInput,
                    name: nameOverride.isEmpty ? nil : nameOverride,
                    category: category
                )

                let newFeed = CustomRSSFeed(
                    feedId: response.feedId,
                    url: response.url,
                    name: response.name,
                    description: response.description,
                    iconUrl: response.iconUrl,
                    category: response.category,
                    createdAt: response.createdAt,
                    lastFetchedAt: nil,
                    isValid: true
                )

                await MainActor.run {
                    onAdd(newFeed)
                    HapticFeedback.success()
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    switch apiError {
                    case .serverError(let message):
                        self.error = message
                    default:
                        self.error = "Failed to add feed"
                    }
                    isAdding = false
                    HapticFeedback.error()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isAdding = false
                    HapticFeedback.error()
                }
            }
        }
    }
}

#Preview {
    RSSFeedsView()
        .environmentObject(AuthService())
}
