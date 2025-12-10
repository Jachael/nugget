import SwiftUI

struct ContentTile: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let tileType: TileType
}

enum TileType: Equatable {
    case catchUp              // All unread nuggets (non-digests)
    case category(String)     // Topic-specific unread nuggets
    case digests              // Unread digest nuggets (grouped)
}

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var badgeManager = NuggetBadgeManager.shared
    @State private var nuggets: [Nugget] = []
    @State private var isLoading = false
    @State private var session: Session?
    @State private var errorMessage: String?
    @State private var greeting: String = ""
    @State private var showStats = false
    @State private var streakBounce = false
    @State private var errorTimer: Timer?
    @State private var showCatchUp = false
    @State private var lastLoadTime = Date.distantPast
    @State private var refreshTask: Task<Void, Never>?
    @State private var showSubscription = false
    @State private var selectedNuggetSession: Session?
    @State private var showRSSFeeds = false
    @State private var showCustomDigests = false
    @State private var showSharedWithMe = false
    @State private var shareToFriendsNugget: Nugget?

    private var isPremium: Bool {
        let tier = authService.currentUser?.subscriptionTier ?? "free"
        return tier == "pro" || tier == "ultimate"
    }

    private var isUltimate: Bool {
        authService.currentUser?.subscriptionTier == "ultimate"
    }

    private var currentTier: String {
        authService.currentUser?.subscriptionTier ?? "free"
    }

    var username: String {
        if let firstName = authService.currentUser?.firstName, !firstName.isEmpty {
            return firstName
        }
        return "friend"
    }

    var unprocessedCount: Int {
        nuggets.filter { $0.summary == nil && $0.isReady }.count
    }

    // Unread digests (RSS feed content with status='digest')
    var unreadDigests: [Nugget] {
        nuggets.filter { nugget in
            nugget.summary != nil &&
            nugget.isReady &&
            nugget.timesReviewed == 0 &&
            (nugget.status == "digest" || // New digest status
             (nugget.status == "inbox" && (nugget.isGrouped == true || nugget.individualSummaries != nil))) // Legacy support
        }
    }

    // Yesterday's unprocessed count
    var yesterdayUnprocessedCount: Int {
        nuggets.filter { Calendar.current.isDateInYesterday($0.createdAt) && $0.summary == nil && $0.isReady }.count
    }

    // Available categories from unprocessed content
    var availableCategories: [String] {
        let categories = nuggets
            .filter { $0.summary == nil && $0.isReady }
            .compactMap { $0.category }

        let counts = Dictionary(grouping: categories, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }

        return counts.map { $0.key }
    }

    var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    // Unread processed nuggets count
    var unreadNuggetsCount: Int {
        nuggets.filter { $0.summary != nil && $0.isReady && $0.timesReviewed == 0 && $0.status == "inbox" }.count
    }

    // Unread nuggets by category (excluding digests - they have their own tile)
    var unreadByCategory: [String: Int] {
        let unread = nuggets.filter {
            $0.summary != nil &&
            $0.isReady &&
            $0.timesReviewed == 0 &&
            $0.status == "inbox" &&
            $0.isGrouped != true &&
            $0.individualSummaries == nil
        }
        return Dictionary(grouping: unread, by: { $0.category ?? "general" })
            .mapValues { $0.count }
    }

    var tiles: [ContentTile] {
        var result: [ContentTile] = []

        // Priority 1: Content tiles - show unread content first

        // Catch Up tile - all unread nuggets (non-digests)
        let nonDigestUnread = nuggets.filter {
            $0.summary != nil &&
            $0.isReady &&
            $0.timesReviewed == 0 &&
            $0.status == "inbox" &&
            $0.isGrouped != true &&
            $0.individualSummaries == nil
        }
        if !nonDigestUnread.isEmpty {
            result.append(ContentTile(
                title: "Catch Up",
                subtitle: "\(nonDigestUnread.count) unread",
                icon: "sparkles",
                color: .purple,
                tileType: .catchUp
            ))
        }

        // Digests tile - unread grouped/digest nuggets
        if !unreadDigests.isEmpty {
            result.append(ContentTile(
                title: "Digests",
                subtitle: "\(unreadDigests.count) unread",
                icon: "square.stack.3d.up",
                color: .indigo,
                tileType: .digests
            ))
        }

        // Topic tiles - categories with unread content
        let categoryIcons: [String: String] = [
            "tech": "desktopcomputer",
            "technology": "desktopcomputer",
            "sport": "sportscourt",
            "sports": "sportscourt",
            "business": "briefcase",
            "finance": "chart.line.uptrend.xyaxis",
            "health": "heart",
            "science": "atom",
            "news": "newspaper",
            "entertainment": "play.tv",
            "career": "person.crop.square"
        ]

        let sortedCategories = unreadByCategory
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(2) // Limit to 2 categories to leave room for other tiles

        for (category, count) in sortedCategories {
            if result.count < 4 {
                let icon = categoryIcons[category.lowercased()] ?? "tag"
                result.append(ContentTile(
                    title: category.capitalized,
                    subtitle: "\(count) unread",
                    icon: icon,
                    color: .blue,
                    tileType: .category(category)
                ))
            }
        }

        return result
    }

    private func getUserLevel(streak: Int) -> String {
        switch streak {
        case 0...6:
            return "Beginner"
        case 7...29:
            return "Intermediate"
        case 30...89:
            return "Expert"
        default:
            return "Power User"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Scrollable content (behind the header)
                ScrollView {
                    VStack(spacing: 24) {
                        // Spacer for fixed header area
                        Color.clear.frame(height: 140)

                    // Error message with auto-dismiss
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.primary.opacity(0.8))
                            Spacer()
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    errorMessage = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.horizontal)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .onAppear {
                            // Auto-dismiss after 10 seconds
                            errorTimer?.invalidate()
                            errorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                                withAnimation(.easeOut(duration: 0.3)) {
                                    errorMessage = nil
                                }
                            }
                        }
                    }

                    // MARK: - Ready to Read Section (Tile-based design)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ready to read?")
                            .font(.title3.bold())
                            .padding(.horizontal)

                        if !tiles.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 16) {
                                ForEach(tiles) { tile in
                                    ContentTileView(tile: tile) {
                                        startSessionForTile(tile)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else if nuggets.isEmpty {
                            // Empty state when no content at all with action tiles
                            VStack(spacing: 16) {
                                VStack(spacing: 12) {
                                    Image(systemName: "plus.app")
                                        .font(.system(size: 36))
                                        .foregroundColor(.secondary)
                                        .symbolRenderingMode(.hierarchical)

                                    Text("Your Feed is empty")
                                        .font(.headline)

                                    Text("Add articles or links to start learning")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 8)

                                // Action tiles grid
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ], spacing: 12) {
                                    ActionTileView(
                                        title: "Subscribe to News",
                                        icon: "newspaper"
                                    ) {
                                        showRSSFeeds = true
                                    }

                                    ActionTileView(
                                        title: "Custom Digest",
                                        icon: "folder.badge.plus"
                                    ) {
                                        showCustomDigests = true
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                            .padding()
                            .glassEffect(in: .rect(cornerRadius: 16))
                            .padding(.horizontal)
                        } else {
                            // All caught up state with action tiles
                            VStack(spacing: 16) {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 36))
                                        .foregroundColor(.secondary)
                                        .symbolRenderingMode(.hierarchical)

                                    Text("You're all caught up!")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 8)

                                // Action tiles grid
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ], spacing: 12) {
                                    ActionTileView(
                                        title: "Subscribe to News",
                                        icon: "newspaper"
                                    ) {
                                        showRSSFeeds = true
                                    }

                                    ActionTileView(
                                        title: "Custom Digest",
                                        icon: "folder.badge.plus"
                                    ) {
                                        showCustomDigests = true
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                            .padding()
                            .glassEffect(in: .rect(cornerRadius: 16))
                            .padding(.horizontal)
                        }

                        // Recent Nuggets Section - show all recent processed nuggets, sorted by newest first
                        let recentNuggets = nuggets.filter { $0.summary != nil && $0.isReady }
                            .sorted { $0.createdAt > $1.createdAt }
                            .prefix(5)
                        if !recentNuggets.isEmpty {
                            Text("Recent Nuggets \(SparkSymbol.spark)")
                                .font(.title3.bold())
                                .padding(.horizontal)
                                .padding(.top, tiles.isEmpty ? 0 : 8)

                            VStack(spacing: 8) {
                                ForEach(Array(recentNuggets)) { nugget in
                                    RecentNuggetRow(nugget: nugget) {
                                        openRecentNugget(nugget)
                                    }
                                    .contextMenu {
                                        Button {
                                            shareToFriendsNugget = nugget
                                        } label: {
                                            Label("Share to Friends", systemImage: "person.2")
                                        }

                                        Button(role: .destructive) {
                                            deleteNugget(nugget)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                        Spacer(minLength: 40)
                    }
                }
                .refreshable {
                    await loadNuggetsAsync()
                    await syncPendingNuggets()
                }

                // Floating header - opaque top section, liquid glass catch-up bar
                VStack(alignment: .leading, spacing: 0) {
                    // Opaque section (title, greeting) - content hidden behind this
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Nugget \(SparkSymbol.spark)")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.primary)

                            Spacer()

                            // Streak button inline with title (no circle)
                            Button {
                                streakBounce.toggle()
                                showStats = true
                                HapticFeedback.light()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "hands.and.sparkles.fill")
                                        .font(.system(size: 14))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.primary, .yellow)
                                        .symbolEffect(.bounce, value: streakBounce)
                                    Text("\(authService.currentUser?.streak ?? 0)")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(.primary)
                            }
                            .buttonStyle(HapticPlainButtonStyle())
                            .onAppear {
                                // Trigger bounce animation on first load
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    streakBounce.toggle()
                                }
                            }
                        }

                        Text("\(timeBasedGreeting), \(username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.systemBackground))

                    // Catch-up bar with liquid glass
                    Button {
                        showCatchUp = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)

                            Text(unprocessedCount > 0 ? "Catch me up on..." : "What would you like to read?")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Capsule())
                        .glassEffect(.regular, in: .capsule)
                    }
                    .buttonStyle(HapticPlainButtonStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("")
            .navigationDestination(item: $session) { session in
                SessionView(session: session)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshNuggets"))) { _ in
                Task {
                    await loadNuggetsAsync()
                }
            }
            .sheet(isPresented: $showStats) {
                StatsView()
                    .presentationCornerRadius(20)
                    .presentationBackgroundInteraction(.enabled)
            }
            .liquidModalTransition(isPresented: showStats)
            .sheet(isPresented: $showCatchUp) {
                CatchUpView(
                    unprocessedCount: unprocessedCount,
                    availableCategories: availableCategories
                ) { newSession in
                    session = newSession
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .liquidModalTransition(isPresented: showCatchUp)
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
            .sheet(isPresented: $showRSSFeeds) {
                RSSFeedsView()
            }
            .sheet(isPresented: $showCustomDigests) {
                CustomDigestsView()
            }
            .sheet(isPresented: $showSharedWithMe) {
                SharedWithMeView()
            }
            .sheet(item: $shareToFriendsNugget) { nugget in
                ShareToFriendsSheet(nuggetId: nugget.nuggetId, nuggetTitle: nugget.title)
            }
            .navigationDestination(item: $selectedNuggetSession) { nuggetSession in
                SessionView(session: nuggetSession)
            }
            .task {
                // Use task instead of onAppear for async loading
                await loadNuggetsAsync()
                await syncPendingNuggets()
                await checkForImmediateProcessing()
            }
        }
    }

    @MainActor
    private func loadNuggetsAsync() async {
        // Cancel any existing refresh task
        refreshTask?.cancel()

        // Implement caching - don't reload if we just loaded
        let timeSinceLastLoad = Date().timeIntervalSince(lastLoadTime)
        if timeSinceLastLoad < 2.0 && !nuggets.isEmpty {
            // Skip refresh if we loaded less than 2 seconds ago
            return
        }

        // Don't show loading indicator on initial load to avoid jank
        if nuggets.isEmpty {
            isLoading = true
        }

        // Create a new refresh task with debouncing
        refreshTask = Task {
            // Small delay to debounce rapid calls
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

            guard !Task.isCancelled else { return }

            do {
                // Fetch inbox and digests in parallel
                async let inboxNuggets = NuggetService.shared.listNuggets(status: "inbox")
                async let digestNuggets = NuggetService.shared.listNuggets(status: "digest")

                let (inbox, digests) = try await (inboxNuggets, digestNuggets)
                let loadedNuggets = inbox + digests

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        nuggets = loadedNuggets
                        isLoading = false
                        lastLoadTime = Date()
                    }
                    // Update badge count for new processed nuggets (inbox only)
                    badgeManager.updateBadgeCount(with: inbox)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isLoading = false
                    print("Failed to load nuggets: \(error)")
                }
            }
        }

        await refreshTask?.value
    }

    private func openRecentNugget(_ nugget: Nugget) {
        // Create a session with just this nugget for the SessionView
        let session = Session(
            sessionId: nil,
            nuggets: [nugget],
            message: nil
        )
        selectedNuggetSession = session
    }

    private func deleteNugget(_ nugget: Nugget) {
        Task {
            do {
                try await NuggetService.shared.deleteNugget(nuggetId: nugget.nuggetId)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        nuggets.removeAll { $0.nuggetId == nugget.nuggetId }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete nugget"
                }
            }
        }
    }

    private func syncPendingNuggets() async {
        // Check if there are pending nuggets from share extension
        if let sharedDefaults = UserDefaults(suiteName: "group.erg.NuggetApp"),
           let pendingNuggets = sharedDefaults.array(forKey: "pendingNuggets") as? [[String: Any]],
           !pendingNuggets.isEmpty {

            for nuggetData in pendingNuggets {
                if let urlString = nuggetData["url"] as? String {
                    do {
                        // Create nugget via API
                        try await NuggetService.shared.createNuggetFromURL(urlString)
                    } catch {
                        print("Failed to create nugget from shared URL: \(error)")
                    }
                }
            }

            // Clear pending nuggets after processing
            sharedDefaults.removeObject(forKey: "pendingNuggets")
            sharedDefaults.synchronize()

            // Reload nuggets to show the new ones
            await loadNuggetsAsync()
        }
    }

    private func checkForImmediateProcessing() async {
        // Check if we should process immediately (from share extension)
        if let sharedDefaults = UserDefaults(suiteName: "group.erg.NuggetApp"),
           sharedDefaults.bool(forKey: "processImmediately") {

            // Reset the flag
            sharedDefaults.removeObject(forKey: "processImmediately")
            sharedDefaults.synchronize()

            // Get the most recent unprocessed nuggets
            let unprocessedNuggets = nuggets.filter { $0.summary == nil && $0.isReady }.prefix(3)

            if unprocessedNuggets.count >= 2 {
                // Process them
                let nuggetsToProcess = Array(unprocessedNuggets)

                Task {
                    do {
                        // Process the nuggets
                        try await PreferencesService.shared.processNuggets(nuggetIds: nuggetsToProcess.map { $0.nuggetId })

                        // Wait for processing
                        try await Task.sleep(nanoseconds: 2_000_000_000)

                        // Start session
                        let newSession = try await NuggetService.shared.startSession(size: nuggetsToProcess.count)

                        await MainActor.run {
                            session = newSession
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = "Failed to process nuggets: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }

    private func startSessionForTile(_ tile: ContentTile) {
        errorMessage = nil

        switch tile.tileType {
        case .catchUp:
            // Show all unread non-digest nuggets directly from local data
            let nonDigestUnread = nuggets.filter {
                $0.summary != nil &&
                $0.isReady &&
                $0.timesReviewed == 0 &&
                $0.status == "inbox" &&
                $0.isGrouped != true &&
                $0.individualSummaries == nil
            }.sorted { $0.createdAt > $1.createdAt }

            if nonDigestUnread.isEmpty {
                errorMessage = "You're all caught up!"
            } else {
                session = Session(
                    sessionId: UUID().uuidString, // Unique ID to force navigation
                    nuggets: nonDigestUnread,
                    message: nil
                )
            }

        case .category(let category):
            // Show unread nuggets for this category directly from local data (excluding digests)
            let categoryUnread = nuggets.filter {
                $0.summary != nil &&
                $0.isReady &&
                $0.timesReviewed == 0 &&
                $0.status == "inbox" &&
                $0.category?.lowercased() == category.lowercased() &&
                $0.isGrouped != true &&
                $0.individualSummaries == nil
            }.sorted { $0.createdAt > $1.createdAt }

            if categoryUnread.isEmpty {
                errorMessage = "No unread \(category) nuggets"
            } else {
                session = Session(
                    sessionId: UUID().uuidString, // Unique ID to force navigation
                    nuggets: categoryUnread,
                    message: nil
                )
            }

        case .digests:
            // Show unread digest nuggets directly from local data
            let digestNuggets = unreadDigests.sorted { $0.createdAt > $1.createdAt }

            if digestNuggets.isEmpty {
                errorMessage = "No unread digests"
            } else {
                session = Session(
                    sessionId: UUID().uuidString, // Unique ID to force navigation
                    nuggets: digestNuggets,
                    message: nil
                )
            }

        }
    }

}

struct ContentTileView: View {
    let tile: ContentTile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: tile.icon)
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tile.color, tile.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(tile.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(tile.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(18)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
        }
        .buttonStyle(HapticPlainButtonStyle())
    }
}

struct ActionTileView: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.primary)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(HapticPlainButtonStyle())
    }
}


struct RecentNuggetRow: View {
    let nugget: Nugget
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Unread indicator dot - only show for unread nuggets
                if nugget.timesReviewed == 0 {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 6, height: 6)
                        .padding(.leading, 4)
                }

                VStack(alignment: .leading, spacing: 6) {
                    if let title = nugget.title {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }

                    if let summary = nugget.summary {
                        Text(summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 12))
        }
        .buttonStyle(HapticPlainButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Digest Row (Unread processed nuggets)
struct DigestRow: View {
    let nugget: Nugget
    let onTap: () -> Void

    var articleCount: Int {
        nugget.individualSummaries?.count ?? 1
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Unread indicator
                Circle()
                    .fill(Color.primary)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(nugget.title ?? "Nugget")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if articleCount > 1 {
                            Text("\(articleCount) articles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let category = nugget.category {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(category.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(HapticPlainButtonStyle())
    }
}

// MARK: - Premium Tip Card
struct PremiumTipCard: View {
    let onUpgrade: () -> Void
    @AppStorage("upgradeTileDismissed") private var isDismissed = false

    private let tips = [
        ("Auto-process your content", "Let AI summarize while you sleep"),
        ("RSS feed support", "Subscribe to your favorite sources"),
        ("Unlimited nuggets", "No daily limits on learning")
    ]

    private var randomTip: (String, String) {
        tips.randomElement() ?? tips[0]
    }

    var body: some View {
        if !isDismissed {
            let tip = randomTip
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tip.0)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(tip.1)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    onUpgrade()
                } label: {
                    Text("Upgrade")
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(12)
                }

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 16))
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.95))
            ))
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService())
}
