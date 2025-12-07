import SwiftUI

struct NuggetsListView: View {
    @State private var nuggets: [Nugget] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedNugget: Nugget?
    @State private var showingNuggetDetail = false
    @State private var lastRefreshTime = Date.distantPast
    @State private var searchText = ""
    @State private var filterProcessed = true
    @State private var filterUnprocessed = true

    var filteredNuggets: [Nugget] {
        var result = nuggets

        // Apply processed/unprocessed filter
        result = result.filter { nugget in
            let isProcessed = nugget.summary != nil
            return (isProcessed && filterProcessed) || (!isProcessed && filterUnprocessed)
        }

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

    var processedCount: Int {
        nuggets.filter { $0.summary != nil }.count
    }

    var unprocessedCount: Int {
        nuggets.filter { $0.summary == nil && $0.isReady }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Nuggets \(SparkSymbol.spark)")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.primary)

                        Spacer()

                        // Stats badge
                        HStack(spacing: 5) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.goldAccent)
                            Text("\(nuggets.count)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("total")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }

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

                    // Filter chips
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "Processed",
                            count: processedCount,
                            isSelected: filterProcessed
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                filterProcessed.toggle()
                            }
                            HapticFeedback.selection()
                        }

                        FilterChip(
                            title: "Unprocessed",
                            count: unprocessedCount,
                            isSelected: filterUnprocessed
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                filterUnprocessed.toggle()
                            }
                            HapticFeedback.selection()
                        }

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background(Color(UIColor.systemBackground))

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
                } else if nuggets.isEmpty {
                    emptyStateView
                } else if filteredNuggets.isEmpty {
                    // No results for current filters
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No nuggets match your filters")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Button("Clear Filters") {
                            withAnimation(.spring(response: 0.3)) {
                                searchText = ""
                                filterProcessed = true
                                filterUnprocessed = true
                            }
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                    }
                    .padding()
                    Spacer()
                } else {
                    // Nuggets list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredNuggets) { nugget in
                                NuggetCard(nugget: nugget) {
                                    selectedNugget = nugget
                                    showingNuggetDetail = true
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        await loadNuggetsAsync()
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNuggetDetail) {
                if let nugget = selectedNugget {
                    NuggetDetailView(nugget: nugget)
                        .presentationCornerRadius(20)
                        .presentationBackgroundInteraction(.enabled)
                }
            }
            .liquidModalTransition(isPresented: showingNuggetDetail)
            .task {
                await loadNuggetsAsync()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshNuggets"))) { _ in
                Task {
                    await loadNuggetsAsync()
                }
            }
        }
    }

    var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text("No Nuggets Yet")
                .font(.title2.bold())

            Text("Save articles, videos, or links to your feed to start building your knowledge library")
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
            let loadedNuggets = try await NuggetService.shared.listNuggets()

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    nuggets = loadedNuggets
                    isLoading = false
                    lastRefreshTime = Date()
                }
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

    var body: some View {
        ParallaxGlassCard {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Status indicator
                    VStack {
                        if isProcessed {
                            GoldCategoryDot()
                        } else {
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        // Title
                        if let title = nugget.title {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
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
                                .foregroundColor(.orange)
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
