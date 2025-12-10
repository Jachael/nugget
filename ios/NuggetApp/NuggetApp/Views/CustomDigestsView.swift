import SwiftUI

struct CustomDigestsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var digests: [CustomDigest] = []
    @State private var availableFeeds: [CatalogFeed] = []
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCreateSheet = false
    @State private var editingDigest: CustomDigest?
    @State private var showDeleteConfirmation = false
    @State private var digestToDelete: CustomDigest?
    @State private var isRunningNow = false
    @State private var showRunSuccess = false

    private var isUltimateUser: Bool {
        authService.currentUser?.subscriptionTier == "ultimate"
    }

    var body: some View {
        NavigationStack {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading digests...")
            } else if !isUltimateUser {
                upgradeRequiredView
            } else if digests.isEmpty {
                emptyStateView
            } else {
                digestListView
            }

            // Floating add button - matches InboxView style
            if isUltimateUser && !isLoading {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showCreateSheet = true
                            HapticFeedback.medium()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 56, height: 56)
                                    .glassEffect(.regular.interactive(), in: .circle)

                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                        .floatingAnimation()
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitle("Custom Digests", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.medium)
            }
        }
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateDigestView(availableFeeds: availableFeeds) { name, feedIds, articlesPerDigest, frequency in
                await createDigest(name: name, feedIds: feedIds, articlesPerDigest: articlesPerDigest, frequency: frequency)
            }
        }
        .sheet(item: $editingDigest) { digest in
            EditDigestView(
                digest: digest,
                availableFeeds: availableFeeds,
                onSave: { name, feedIds, isEnabled, articlesPerDigest, frequency in
                    await updateDigest(digestId: digest.digestId, name: name, feedIds: feedIds, isEnabled: isEnabled, articlesPerDigest: articlesPerDigest, frequency: frequency)
                },
                onDelete: {
                    digestToDelete = digest
                    editingDigest = nil
                    showDeleteConfirmation = true
                }
            )
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Delete Digest?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                digestToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let digest = digestToDelete {
                    Task {
                        await deleteDigest(digestId: digest.digestId)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(digestToDelete?.name ?? "")\"? This cannot be undone.")
        }
        }
    }

    // MARK: - Views

    private var upgradeRequiredView: some View {
        PremiumFeatureGate(
            feature: "Custom Digests",
            description: "Combine multiple RSS feeds into personalized daily summaries.",
            icon: "folder.fill",
            requiredTier: "Ultimate"
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("No Custom Digests")
                .font(.title2)
                .fontWeight(.bold)

            Text("Create a custom digest to combine articles from multiple RSS feeds into one personalized summary.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: { showCreateSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Your First Digest")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassProminentButtonStyle())
            .padding(.horizontal)
        }
        .padding()
    }

    private var digestListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Run Now button
                Button(action: {
                    Task {
                        await runFetchNow()
                    }
                }) {
                    HStack {
                        if isRunningNow {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isRunningNow ? "Fetching..." : "Run Digests Now")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isRunningNow)

                ForEach(digests) { digest in
                    DigestCard(
                        digest: digest,
                        feedNames: getFeedNames(for: digest),
                        onTap: {
                            editingDigest = digest
                        },
                        onToggle: { isEnabled in
                            Task {
                                await updateDigest(digestId: digest.digestId, name: nil, feedIds: nil, isEnabled: isEnabled, articlesPerDigest: nil, frequency: nil)
                            }
                        }
                    )
                }
            }
            .padding()
        }
        .alert("Started", isPresented: $showRunSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Feed fetch started! New nuggets will appear in your inbox in about 30-60 seconds.")
        }
    }

    // MARK: - Helpers

    private func getFeedNames(for digest: CustomDigest) -> [String] {
        digest.feedIds.compactMap { feedId in
            availableFeeds.first { $0.id == feedId }?.name
        }
    }

    // MARK: - API Calls

    private func loadData() {
        isLoading = true
        Task {
            do {
                async let digestsResponse = FeedService.shared.getDigests()
                async let feedsResponse = FeedService.shared.getFeeds()

                let (digestsResult, feedsResult) = try await (digestsResponse, feedsResponse)

                await MainActor.run {
                    self.digests = digestsResult.digests
                    // Only show feeds that the user is subscribed to
                    self.availableFeeds = feedsResult.catalog.filter { $0.isSubscribed }
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

    private func createDigest(name: String, feedIds: [String], articlesPerDigest: Int, frequency: DigestFrequency) async {
        do {
            let response = try await FeedService.shared.createDigest(
                name: name,
                feedIds: feedIds,
                articlesPerDigest: articlesPerDigest,
                frequency: frequency
            )
            await MainActor.run {
                if let digest = response.digest {
                    self.digests.append(digest)
                }
                self.showCreateSheet = false
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }

    private func updateDigest(digestId: String, name: String?, feedIds: [String]?, isEnabled: Bool?, articlesPerDigest: Int? = nil, frequency: DigestFrequency? = nil) async {
        do {
            let response = try await FeedService.shared.updateDigest(
                digestId: digestId,
                name: name,
                feedIds: feedIds,
                isEnabled: isEnabled,
                articlesPerDigest: articlesPerDigest,
                frequency: frequency
            )
            await MainActor.run {
                if let updatedDigest = response.digest,
                   let index = self.digests.firstIndex(where: { $0.digestId == digestId }) {
                    self.digests[index] = updatedDigest
                }
                self.editingDigest = nil
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }

    private func deleteDigest(digestId: String) async {
        do {
            _ = try await FeedService.shared.deleteDigest(digestId: digestId)
            await MainActor.run {
                self.digests.removeAll { $0.digestId == digestId }
                self.digestToDelete = nil
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }

    private func runFetchNow() async {
        await MainActor.run {
            isRunningNow = true
        }

        do {
            _ = try await FeedService.shared.fetchAllFeeds()
            await MainActor.run {
                self.isRunningNow = false
                self.showRunSuccess = true
                // Reload digests to get updated lastGeneratedAt
                loadData()
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                self.isRunningNow = false
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
}

// MARK: - Digest Card

struct DigestCard: View {
    let digest: CustomDigest
    let feedNames: [String]
    let onTap: () -> Void
    let onToggle: (Bool) -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(digest.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("\(feedNames.count) feed\(feedNames.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { digest.isEnabled },
                        set: { onToggle($0) }
                    ))
                    .labelsHidden()
                }

                if !feedNames.isEmpty {
                    Text(feedNames.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                        Text("\(digest.articlesPerDigest) articles")
                            .font(.caption2)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(digest.frequency.displayName)
                            .font(.caption2)
                    }
                }
                .foregroundColor(.secondary)

                if let lastGenerated = digest.lastGeneratedAt {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                        Text("Last: \(formatDate(lastGenerated))")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatDate(_ isoString: String) -> String {
        // Handle Unix timestamp (seconds since epoch)
        if let timestamp = Double(isoString) {
            let date = Date(timeIntervalSince1970: timestamp)
            return formatRelativeDate(date)
        }

        // Handle ISO8601 string
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return formatRelativeDate(date)
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return formatRelativeDate(date)
        }

        return isoString
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday at \(formatter.string(from: date))"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE 'at' h:mm a"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Digest Configuration

struct DigestConfig {
    var articlesPerDigest: ArticlesPerDigest = .five
    var frequency: DigestFrequency = .withSchedule
}

// MARK: - Create Digest View

struct CreateDigestView: View {
    @Environment(\.presentationMode) var presentationMode
    let availableFeeds: [CatalogFeed]
    let onCreate: (String, [String], Int, DigestFrequency) async -> Void

    @State private var name = ""
    @State private var selectedFeedIds: Set<String> = []
    @State private var config = DigestConfig()
    @State private var isCreating = false

    private var feedsByCategory: [String: [CatalogFeed]] {
        Dictionary(grouping: availableFeeds, by: { $0.category })
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Digest Name")) {
                    TextField("e.g., My Tech Roundup", text: $name)
                }

                Section(header: Text("Configuration")) {
                    Picker("Articles per digest", selection: $config.articlesPerDigest) {
                        ForEach(ArticlesPerDigest.allCases) { count in
                            Text(count.displayName).tag(count)
                        }
                    }

                    Picker("Frequency", selection: $config.frequency) {
                        ForEach(DigestFrequency.allCases) { freq in
                            VStack(alignment: .leading) {
                                Text(freq.displayName)
                            }
                            .tag(freq)
                        }
                    }

                    Text(config.frequency.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Select Feeds (\(selectedFeedIds.count)/10)")) {
                    if availableFeeds.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "rss")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No Subscribed Feeds")
                                .font(.headline)
                            Text("Subscribe to RSS feeds first to create a custom digest.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(feedsByCategory.keys.sorted(), id: \.self) { category in
                            DisclosureGroup(category.capitalized) {
                                ForEach(feedsByCategory[category] ?? []) { feed in
                                    FeedSelectionRow(
                                        feed: feed,
                                        isSelected: selectedFeedIds.contains(feed.id),
                                        onToggle: {
                                            if selectedFeedIds.contains(feed.id) {
                                                selectedFeedIds.remove(feed.id)
                                            } else if selectedFeedIds.count < 10 {
                                                selectedFeedIds.insert(feed.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("New Digest", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: {
                    Task {
                        isCreating = true
                        await onCreate(
                            name,
                            Array(selectedFeedIds),
                            config.articlesPerDigest.rawValue,
                            config.frequency
                        )
                        isCreating = false
                    }
                }) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Text("Create")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(name.isEmpty || selectedFeedIds.isEmpty || isCreating)
            )
        }
    }
}

// MARK: - Edit Digest View

struct EditDigestView: View {
    @Environment(\.presentationMode) var presentationMode
    let digest: CustomDigest
    let availableFeeds: [CatalogFeed]
    let onSave: (String?, [String]?, Bool?, Int?, DigestFrequency?) async -> Void
    let onDelete: () -> Void

    @State private var name: String
    @State private var selectedFeedIds: Set<String>
    @State private var isEnabled: Bool
    @State private var articlesPerDigest: ArticlesPerDigest
    @State private var frequency: DigestFrequency
    @State private var isSaving = false

    init(digest: CustomDigest, availableFeeds: [CatalogFeed], onSave: @escaping (String?, [String]?, Bool?, Int?, DigestFrequency?) async -> Void, onDelete: @escaping () -> Void) {
        self.digest = digest
        self.availableFeeds = availableFeeds
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: digest.name)
        _selectedFeedIds = State(initialValue: Set(digest.feedIds))
        _isEnabled = State(initialValue: digest.isEnabled)
        _articlesPerDigest = State(initialValue: ArticlesPerDigest(rawValue: digest.articlesPerDigest) ?? .five)
        _frequency = State(initialValue: digest.frequency)
    }

    private var feedsByCategory: [String: [CatalogFeed]] {
        Dictionary(grouping: availableFeeds, by: { $0.category })
    }

    private var hasChanges: Bool {
        name != digest.name ||
        Set(digest.feedIds) != selectedFeedIds ||
        isEnabled != digest.isEnabled ||
        articlesPerDigest.rawValue != digest.articlesPerDigest ||
        frequency != digest.frequency
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Digest Name")) {
                    TextField("Digest name", text: $name)
                }

                Section(header: Text("Status")) {
                    Toggle("Generate this digest", isOn: $isEnabled)
                }

                Section(header: Text("Configuration")) {
                    Picker("Articles per digest", selection: $articlesPerDigest) {
                        ForEach(ArticlesPerDigest.allCases) { count in
                            Text(count.displayName).tag(count)
                        }
                    }

                    Picker("Frequency", selection: $frequency) {
                        ForEach(DigestFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }

                    Text(frequency.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Select Feeds (\(selectedFeedIds.count)/10)")) {
                    ForEach(feedsByCategory.keys.sorted(), id: \.self) { category in
                        DisclosureGroup(category.capitalized) {
                            ForEach(feedsByCategory[category] ?? []) { feed in
                                FeedSelectionRow(
                                    feed: feed,
                                    isSelected: selectedFeedIds.contains(feed.id),
                                    onToggle: {
                                        if selectedFeedIds.contains(feed.id) {
                                            selectedFeedIds.remove(feed.id)
                                        } else if selectedFeedIds.count < 10 {
                                            selectedFeedIds.insert(feed.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }

                Section {
                    Button(action: onDelete) {
                        HStack {
                            Spacer()
                            Text("Delete Digest")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationBarTitle("Edit Digest", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: {
                    Task {
                        isSaving = true
                        await onSave(
                            name != digest.name ? name : nil,
                            Set(digest.feedIds) != selectedFeedIds ? Array(selectedFeedIds) : nil,
                            isEnabled != digest.isEnabled ? isEnabled : nil,
                            articlesPerDigest.rawValue != digest.articlesPerDigest ? articlesPerDigest.rawValue : nil,
                            frequency != digest.frequency ? frequency : nil
                        )
                        isSaving = false
                    }
                }) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(!hasChanges || name.isEmpty || selectedFeedIds.isEmpty || isSaving)
            )
        }
    }
}

// MARK: - Feed Selection Row

struct FeedSelectionRow: View {
    let feed: CatalogFeed
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(feed.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text(feed.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.purple)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomDigestsView_Previews: PreviewProvider {
    static var previews: some View {
        CustomDigestsView()
            .environmentObject(AuthService())
    }
}
