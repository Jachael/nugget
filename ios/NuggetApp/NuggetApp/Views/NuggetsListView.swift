import SwiftUI

struct NuggetsListView: View {
    @State private var nuggets: [Nugget] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedNuggetSession: Session?
    @State private var lastRefreshTime = Date.distantPast
    @State private var searchText = ""
    @StateObject private var badgeManager = NuggetBadgeManager.shared

    /// Only show fully processed nuggets (those with summaries and ready state)
    var processedNuggets: [Nugget] {
        nuggets.filter { $0.summary != nil && $0.isReady }
    }

    var filteredNuggets: [Nugget] {
        var result = processedNuggets

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { nugget in
                let titleMatch = nugget.title?.lowercased().contains(searchText.lowercased()) ?? false
                let summaryMatch = nugget.summary?.lowercased().contains(searchText.lowercased()) ?? false
                let categoryMatch = nugget.category?.lowercased().contains(searchText.lowercased()) ?? false
                return titleMatch || summaryMatch || categoryMatch
            }
        }

        // Sort by creation date, newest first
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    var totalCount: Int {
        processedNuggets.count
    }

    var unreadCount: Int {
        processedNuggets.filter { $0.timesReviewed == 0 }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                VStack(spacing: 12) {
                    // Search bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)

                        TextField("Search nuggets...", text: $searchText)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                HapticFeedback.light()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .glassEffect(in: .capsule)

                    // Nugget count with unread
                    HStack(spacing: 8) {
                        Text("\(totalCount) nugget\(totalCount == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if unreadCount > 0 {
                            Text("•")
                                .foregroundColor(.secondary.opacity(0.5))

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.primary)
                                    .frame(width: 6, height: 6)
                                Text("\(unreadCount) unread")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Content
                if isLoading && nuggets.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading nuggets...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            loadNuggets()
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                    }
                    .padding()
                    Spacer()
                } else if processedNuggets.isEmpty {
                    emptyStateView
                } else if filteredNuggets.isEmpty {
                    // No results for search
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No nuggets match your search")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Button("Clear Search") {
                            withAnimation(.spring(response: 0.3)) {
                                searchText = ""
                            }
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                    }
                    .padding()
                    Spacer()
                } else {
                    // Nuggets list
                    List {
                        ForEach(filteredNuggets) { nugget in
                            NuggetCard(nugget: nugget) {
                                // Create a session with just this nugget for the SessionView
                                let session = Session(
                                    sessionId: nil,
                                    nuggets: [nugget],
                                    message: nil
                                )
                                selectedNuggetSession = session
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let nugget = filteredNuggets[index]
                                deleteNugget(nugget)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .refreshable {
                        await loadNuggetsAsync()
                    }
                }
            }
            .navigationTitle("Nuggets")
            .navigationDestination(item: $selectedNuggetSession) { nuggetSession in
                SessionView(session: nuggetSession)
            }
            .task {
                await loadNuggetsAsync()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshNuggets"))) { _ in
                Task {
                    await loadNuggetsAsync()
                }
            }
            .onAppear {
                // Mark all nuggets as seen when viewing the Nuggets tab
                badgeManager.markAllAsSeen(nuggets)
            }
            .onChange(of: nuggets) { _, newNuggets in
                // When nuggets change and user is viewing this tab, mark as seen
                badgeManager.markAllAsSeen(newNuggets)
            }
        }
    }

    var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text("No nuggets yet")
                .font(.title3)
                .fontWeight(.medium)

            Text("Save articles or links to your feed to start building your knowledge library")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func loadNuggetsAsync() async {
        // Implement caching - don't reload if we just loaded
        let timeSinceLastLoad = Date().timeIntervalSince(lastRefreshTime)
        if timeSinceLastLoad < 2.0 && !nuggets.isEmpty {
            return
        }

        if nuggets.isEmpty {
            isLoading = true
        }
        errorMessage = nil

        do {
            // Fetch both inbox and digest nuggets to show all processed content
            async let inboxNuggets = NuggetService.shared.listNuggets(status: "inbox")
            async let digestNuggets = NuggetService.shared.listNuggets(status: "digest")

            let (inbox, digest) = try await (inboxNuggets, digestNuggets)
            let allNuggets = inbox + digest

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    nuggets = allNuggets
                    isLoading = false
                    lastRefreshTime = Date()
                }
                // Update badge count (will be cleared since user is viewing this tab)
                badgeManager.updateBadgeCount(with: allNuggets)
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to load nuggets: \(error.localizedDescription)"
            }
        }
    }

    private func loadNuggets() {
        Task {
            await loadNuggetsAsync()
        }
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
}

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.goldAccent)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                }

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Text("(\(count))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(isSelected ? .regular.interactive() : .regular, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

struct NuggetCard: View {
    let nugget: Nugget
    let onTap: () -> Void
    @State private var scrollOffset: CGFloat = 0

    var isProcessed: Bool {
        nugget.summary != nil
    }

    var isUnread: Bool {
        nugget.timesReviewed == 0
    }

    var body: some View {
        ParallaxGlassCard {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Unread indicator - only show for unread items
                    if isUnread {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        // Title
                        if let title = nugget.title {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(isUnread ? .bold : .medium)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }

                        // Summary or processing state
                        if let summary = nugget.summary {
                            Text(summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        } else if nugget.isReady {
                            Text("Unprocessed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            Text("Processing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }

                        // Metadata row
                        HStack(spacing: 8) {
                            if let category = nugget.category {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .font(.system(size: 9))
                                    Text(category.capitalized)
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.secondary)
                            }

                            Text("•")
                                .foregroundColor(.secondary.opacity(0.5))

                            Text(formatDate(nugget.createdAt))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            if nugget.timesReviewed > 0 {
                                Text("•")
                                    .foregroundColor(.secondary.opacity(0.5))

                                HStack(spacing: 4) {
                                    Image(systemName: "eye.fill")
                                        .font(.system(size: 9))
                                    Text("\(nugget.timesReviewed)")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 16))
                .overlay(
                    FaintGradientHeader()
                        .mask(RoundedRectangle(cornerRadius: 16))
                        .allowsHitTesting(false),
                    alignment: .top
                )
            }
            .buttonStyle(.plain)
        }
        .glassShadowDrift(scrollOffset: scrollOffset)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { oldValue, newValue in
            scrollOffset = newValue - (oldValue ?? 0)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo < 7 {
            return "\(daysAgo)d ago"
        } else if let weeksAgo = calendar.dateComponents([.weekOfYear], from: date, to: now).weekOfYear, weeksAgo < 4 {
            return "\(weeksAgo)w ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    NuggetsListView()
        .environmentObject(AuthService())
}
