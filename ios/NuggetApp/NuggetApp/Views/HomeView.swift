import SwiftUI

struct ContentTile: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let filter: TileFilter
}

enum TileFilter {
    case thisWeek
    case today
    case yesterday
    case category(String)
}

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var nuggets: [Nugget] = []
    @State private var isLoading = false
    @State private var session: Session?
    @State private var errorMessage: String?
    @State private var greeting: String = ""
    @State private var showTestWebView = false
    @State private var showStats = false
    @State private var errorTimer: Timer?
    @State private var nuggetToDelete: Nugget?
    @State private var showDeleteConfirmation = false
    @State private var showSmartProcess = false

    var username: String {
        authService.currentUser?.userId.prefix(8).description ?? "friend"
    }

    var unprocessedCount: Int {
        nuggets.filter { $0.summary == nil }.count
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

    var tiles: [ContentTile] {
        var result: [ContentTile] = []

        // This week tile
        let thisWeekCount = nuggets.filter { nugget in
            guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return false }
            return nugget.createdAt >= weekAgo && nugget.summary == nil
        }.count

        if thisWeekCount > 0 {
            result.append(ContentTile(
                title: "This Week",
                subtitle: "\(thisWeekCount) nuggets",
                icon: "calendar.badge.clock",
                color: .secondary,
                filter: .thisWeek
            ))
        }

        // Today tile
        let todayCount = nuggets.filter { Calendar.current.isDateInToday($0.createdAt) && $0.summary == nil }.count
        if todayCount > 0 {
            result.append(ContentTile(
                title: "Today",
                subtitle: "\(todayCount) nuggets",
                icon: "sun.max.fill",
                color: .secondary,
                filter: .today
            ))
        }

        // Yesterday tile
        let yesterdayCount = nuggets.filter { Calendar.current.isDateInYesterday($0.createdAt) && $0.summary == nil }.count
        if yesterdayCount > 0 {
            result.append(ContentTile(
                title: "Yesterday",
                subtitle: "\(yesterdayCount) nuggets",
                icon: "moon.stars.fill",
                color: .secondary,
                filter: .yesterday
            ))
        }

        // Category tiles - get top categories
        let categories = Dictionary(grouping: nuggets.filter { $0.summary == nil }, by: { $0.category ?? "general" })
        let topCategories = categories.sorted { $0.value.count > $1.value.count }.prefix(3)

        for (category, items) in topCategories {
            let color: Color = .secondary

            result.append(ContentTile(
                title: category.capitalized,
                subtitle: "\(items.count) nuggets",
                icon: "tag.fill",
                color: color,
                filter: .category(category)
            ))
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
            ScrollView {
                VStack(spacing: 24) {
                    // Header with greeting and streak
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nugget")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.top, 16)

                        // Search bar for Smart Processing
                        if unprocessedCount > 0 {
                            Button {
                                showSmartProcess = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)

                                    Text("Search \(unprocessedCount) saved items...")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .glassEffect(in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }

                        HStack {
                            Text("\(timeBasedGreeting), \(username)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            // Clickable streak on the right - Liquid Glass
                            Button {
                                showStats = true
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange)
                                    Text("\(authService.currentUser?.streak ?? 0)")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("days")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(GlassButtonStyle())
                        }
                        .padding(.top, -4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Error message with auto-dismiss
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange.opacity(0.8))
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
                        .glassEffect(.regular.tint(.orange), in: .capsule)
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

                    // Dynamic content tiles - always show this section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Catch up on")
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
                        } else {
                            // Encouragement message when no content available
                            VStack(spacing: 16) {
                                Image(systemName: "plus.app")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                    .symbolRenderingMode(.hierarchical)

                                Text("No content to process")
                                    .font(.headline)

                                Text("Add articles, videos, or links to your feed to start learning")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)

                                NavigationLink(destination: InboxView()) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Content")
                                    }
                                }
                                .buttonStyle(GlassProminentButtonStyle())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal)
                            .glassEffect(in: .rect(cornerRadius: 16))
                            .padding(.horizontal)
                        }

                        // Recent Nuggets
                        let recentNuggets = nuggets.filter { $0.summary != nil }.prefix(3)
                        if !recentNuggets.isEmpty {
                            Text("Recent Nuggets")
                                .font(.title3.bold())
                                .padding(.horizontal)
                                .padding(.top, tiles.isEmpty ? 0 : 16)

                            List {
                                ForEach(Array(recentNuggets)) { nugget in
                                    RecentNuggetRow(nugget: nugget) {
                                        openRecentNugget(nugget)
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            nuggetToDelete = nugget
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .frame(height: CGFloat(recentNuggets.count) * 110)
                            .scrollDisabled(true)
                        }

                        // Quick Actions section
                        Text("Quick Actions")
                            .font(.title3.bold())
                            .padding(.horizontal)
                            .padding(.top, tiles.isEmpty ? 0 : 16)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            // Browse Feed
                            NavigationLink(destination: InboxView()) {
                                QuickActionTile(
                                    title: "Browse Feed",
                                    subtitle: "\(nuggets.count) articles",
                                    icon: "list.bullet.rectangle.fill",
                                    action: nil
                                )
                            }

                            // Total Categories
                            QuickActionTile(
                                title: "Categories",
                                subtitle: "\(Set(nuggets.compactMap { $0.category }).count) topics",
                                icon: "tag.fill",
                                action: nil
                            )
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("")
            .navigationDestination(item: $session) { session in
                SessionView(session: session)
            }
            .fullScreenCover(isPresented: $showTestWebView) {
                TestWebView()
            }
            .sheet(isPresented: $showStats) {
                StatsView()
            }
            .sheet(isPresented: $showSmartProcess) {
                SmartProcessView(unprocessedCount: unprocessedCount) { newSession in
                    // Session will be created by SmartProcessView
                    session = newSession
                }
            }
            .confirmationDialog(
                "Delete Nugget?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let nugget = nuggetToDelete {
                        deleteNugget(nugget)
                    }
                }
                Button("Cancel", role: .cancel) {
                    nuggetToDelete = nil
                }
            } message: {
                Text("This action cannot be undone.")
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
        // Don't show loading indicator on initial load to avoid jank
        if nuggets.isEmpty {
            isLoading = true
        }

        do {
            let loadedNuggets = try await NuggetService.shared.listNuggets()
            withAnimation(.easeInOut(duration: 0.2)) {
                nuggets = loadedNuggets
                isLoading = false
            }
        } catch {
            isLoading = false
            print("Failed to load nuggets: \(error)")
        }
    }

    private func openRecentNugget(_ nugget: Nugget) {
        // Create a session with just this nugget
        let newSession = Session(
            sessionId: nil,
            nuggets: [nugget],
            message: nil
        )
        session = newSession
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
            let unprocessedNuggets = nuggets.filter { $0.summary == nil }.prefix(3)

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

        let filteredNuggets: [Nugget]

        switch tile.filter {
        case .thisWeek:
            guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return }
            filteredNuggets = nuggets.filter { $0.createdAt >= weekAgo && $0.summary == nil }
        case .today:
            filteredNuggets = nuggets.filter { Calendar.current.isDateInToday($0.createdAt) && $0.summary == nil }
        case .yesterday:
            filteredNuggets = nuggets.filter { Calendar.current.isDateInYesterday($0.createdAt) && $0.summary == nil }
        case .category(let category):
            filteredNuggets = nuggets.filter { $0.category?.lowercased() == category.lowercased() && $0.summary == nil }
        }

        guard filteredNuggets.count >= 2 else {
            errorMessage = "Add at least 2 items to process"
            return
        }

        // Take up to 3 nuggets for the session
        let nuggetsToProcess = Array(filteredNuggets.prefix(3))

        Task {
            do {
                // Process the nuggets first
                try await PreferencesService.shared.processNuggets(nuggetIds: nuggetsToProcess.map { $0.nuggetId })

                // Wait a bit for processing
                try await Task.sleep(nanoseconds: 3_000_000_000)

                // Start the session
                let newSession = try await NuggetService.shared.startSession(size: min(nuggetsToProcess.count, 3))
                await MainActor.run {
                    session = newSession
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to start session: \(error.localizedDescription)"
                }
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
        .buttonStyle(.plain)
    }
}

struct QuickActionTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.primary.opacity(0.7))
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(18)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

struct RecentNuggetRow: View {
    let nugget: Nugget
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
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
        .buttonStyle(.plain)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService())
}
