import SwiftUI

struct RSSFeedsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var feeds: [CatalogFeed] = []
    @State private var subscriptions: [FeedSubscription] = []
    @State private var isLoading = true
    @State private var isFetching = false
    @State private var error: String?
    @State private var successMessage: String?
    @State private var showingUpgradePrompt = false
    @State private var selectedCategory: String?

    private var isPremium: Bool {
        let tier = authService.currentUser?.subscriptionTier ?? "free"
        return tier == "pro"
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
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("RSS Feeds")
                                .font(.largeTitle.bold())
                                .foregroundColor(.primary)

                            Text("Subscribe to quality news sources and get AI-powered daily recaps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top)

                        // Status messages
                        if let successMessage = successMessage {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(successMessage)
                                    .font(.subheadline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        if let error = error {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.subheadline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
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
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text(isFetching ? "Fetching feeds..." : "Fetch Latest Content")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
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

                        // Feed list
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredFeeds) { feed in
                                    FeedRow(
                                        feed: feed,
                                        isPremium: isPremium,
                                        onToggle: {
                                            Task {
                                                await toggleSubscription(feed: feed)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await loadFeeds()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }

    private func loadFeeds() async {
        isLoading = true
        error = nil

        do {
            let response = try await FeedService.shared.getFeeds()
            feeds = response.catalog
            subscriptions = response.subscriptions
            isLoading = false
        } catch {
            self.error = "Failed to load feeds: \(error.localizedDescription)"
            isLoading = false
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
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(feed.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if feed.isPremium {
                            Text("PRO")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }
                    }

                    Text(feed.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Text(feed.category.capitalized)
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Spacer()

                Toggle("", isOn: .constant(feed.isSubscribed))
                    .labelsHidden()
                    .disabled(feed.isPremium && !isPremium && !feed.isSubscribed)
                    .onChange(of: feed.isSubscribed) { _ in
                        onToggle()
                    }
                    .onTapGesture {
                        onToggle()
                    }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Category Filter Chip
struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .cornerRadius(20)
        }
    }
}

#Preview {
    RSSFeedsView()
        .environmentObject(AuthService())
}
