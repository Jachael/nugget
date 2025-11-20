import SwiftUI

enum FeedFilter: String, CaseIterable {
    case all = "All"
    case business = "Business"
    case sport = "Sport"
    case technology = "Technology"
    case career = "Career"
    case health = "Health"
    case science = "Science"
    case entertainment = "Entertainment"
    case politics = "Politics"
    case education = "Education"

    var categoryKey: String? {
        switch self {
        case .all: return nil
        default: return self.rawValue.lowercased()
        }
    }
}

enum TimeFilter: String, CaseIterable {
    case all = "All Time"
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"

    func matches(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDateInToday(date)
        case .yesterday:
            return calendar.isDateInYesterday(date)
        case .thisWeek:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return false }
            return date >= weekAgo
        case .thisMonth:
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else { return false }
            return date >= monthAgo
        }
    }
}

enum SortOrder: String, CaseIterable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case processed = "Processed First"
    case unprocessed = "Unprocessed First"

    var icon: String {
        switch self {
        case .newestFirst: return "arrow.down.circle"
        case .oldestFirst: return "arrow.up.circle"
        case .processed: return "checkmark.seal"
        case .unprocessed: return "clock"
        }
    }
}

struct InboxView: View {
    @State private var nuggets: [Nugget] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddNugget = false
    @State private var isProcessing = false
    @State private var showProcessSuccess = false
    @State private var selectedCategory: FeedFilter = .all
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var selectedSortOrder: SortOrder = .newestFirst
    @State private var isLoadingMore = false
    @State private var hasInitiallyLoaded = false
    @State private var lastRefreshTime = Date.distantPast

    var scrapedNuggets: [Nugget] {
        sortedFilteredNuggets.filter { $0.summary == nil }
    }

    var sortedFilteredNuggets: [Nugget] {
        let filtered = nuggets.filter { nugget in
            // Category filter
            let categoryMatch: Bool
            if let categoryKey = selectedCategory.categoryKey {
                categoryMatch = nugget.category?.lowercased() == categoryKey
            } else {
                categoryMatch = true
            }

            // Time filter
            let timeMatch = selectedTimeFilter.matches(nugget.createdAt)

            return categoryMatch && timeMatch
        }

        // Apply sorting
        return filtered.sorted { nugget1, nugget2 in
            switch selectedSortOrder {
            case .newestFirst:
                return nugget1.createdAt > nugget2.createdAt
            case .oldestFirst:
                return nugget1.createdAt < nugget2.createdAt
            case .processed:
                // Processed items first, then by date
                if nugget1.summary != nil && nugget2.summary == nil {
                    return true
                } else if nugget1.summary == nil && nugget2.summary != nil {
                    return false
                } else {
                    return nugget1.createdAt > nugget2.createdAt
                }
            case .unprocessed:
                // Unprocessed items first, then by date
                if nugget1.summary == nil && nugget2.summary != nil {
                    return true
                } else if nugget1.summary != nil && nugget2.summary == nil {
                    return false
                } else {
                    return nugget1.createdAt > nugget2.createdAt
                }
            }
        }
    }

    // Keep the old name for compatibility but use the sorted version
    var filteredNuggets: [Nugget] {
        sortedFilteredNuggets
    }

    var canProcess: Bool {
        scrapedNuggets.count >= 2
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Filter bar - always visible at top
                    filterBar

                    // Content area
                    if isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text(error)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                loadNuggets()
                            }
                            .buttonStyle(GlassButtonStyle())
                        }
                        .padding()
                        Spacer()
                    } else if nuggets.isEmpty {
                        emptyStateView
                    } else {
                                VStack(spacing: 0) {
                                    if !scrapedNuggets.isEmpty {
                                        ProcessBanner(
                                            count: scrapedNuggets.count,
                                            isProcessing: isProcessing,
                                            canProcess: canProcess,
                                            onProcess: processNuggets
                                        )
                                    }

                                    if filteredNuggets.isEmpty {
                                        VStack(spacing: 16) {
                                            Image(systemName: "line.3.horizontal.decrease.circle")
                                                .font(.system(size: 50))
                                                .foregroundColor(.secondary)
                                            Text("No nuggets match your filters")
                                                .font(.headline)
                                                .foregroundColor(.secondary)
                                            Button("Clear Filters") {
                                                selectedCategory = .all
                                                selectedTimeFilter = .all
                                            }
                                            .buttonStyle(GlassButtonStyle())
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    } else {
                                        List {
                                            ForEach(filteredNuggets) { nugget in
                                                NavigationLink(destination: NuggetDetailView(nugget: nugget)) {
                                                    NuggetRowView(nugget: nugget)
                                                }
                                                .listRowBackground(Color.clear)
                                            }
                                            .onDelete(perform: deleteNuggets)
                                        }
                                        .listStyle(.plain)
                                        .scrollContentBackground(.hidden)
                                        .refreshable {
                                            await refreshNuggets()
                                        }
                                    }
                                }
                    }
                }

                // Floating Action Button - Liquid Glass
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            // Prevent double-tap
                            guard !showingAddNugget else { return }
                            showingAddNugget = true
                            HapticFeedback.medium()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.goldAccent.opacity(0.1), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 56, height: 56)
                                    .glassEffect(.regular.interactive(), in: .circle)

                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                        .disabled(showingAddNugget)
                        .floatingAnimation()
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Feed \(SparkSymbol.spark)")
            .alert("Nuggets Processing", isPresented: $showProcessSuccess) {
                Button("OK") { }
            } message: {
                Text("Your nuggets are being processed. This may take a minute. Refresh to see the results.")
            }
            .sheet(isPresented: $showingAddNugget) {
                AddNuggetView { nugget in
                    nuggets.insert(nugget, at: 0)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .liquidModalTransition(isPresented: showingAddNugget)
            .task {
                // Load content asynchronously
                await loadNuggetsIfNeeded()
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Sort dropdown
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSortOrder = order
                            }
                        } label: {
                            HStack {
                                Image(systemName: order.icon)
                                Text(order.rawValue)
                                if selectedSortOrder == order {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedSortOrder.icon)
                            .font(.caption)
                        Text(selectedSortOrder.rawValue)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(in: .capsule)
                }

                // Category dropdown
                Menu {
                    ForEach(FeedFilter.allCases, id: \.self) { filter in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = filter
                            }
                        } label: {
                            HStack {
                                Text(filter.rawValue)
                                if selectedCategory == filter {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.caption)
                    Text(selectedCategory.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(in: .capsule)
            }

            // Time dropdown
            Menu {
                ForEach(TimeFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedTimeFilter = filter
                    } label: {
                        HStack {
                            Text(filter.rawValue)
                            if selectedTimeFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text(selectedTimeFilter.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(in: .capsule)
            }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: .rect)
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "tray")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text("No nuggets yet")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Tap + to save your first piece of content")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 20))
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func loadNuggets() {
        Task {
            await loadNuggetsAsync()
        }
    }

    private func refreshNuggets() async {
        do {
            // Check for and process any pending nuggets from share extension
            let hadPendingNuggets = try await NuggetService.shared.processPendingSharedNuggets()

            // Then load all nuggets
            let loadedNuggets = try await NuggetService.shared.listNuggets()
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Only update if there are actual changes
                    if loadedNuggets != nuggets {
                        nuggets = loadedNuggets
                    }
                    lastRefreshTime = Date()
                }
            }

            // If we had pending nuggets, notify HomeView
            if hadPendingNuggets {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshNuggets"), object: nil)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to refresh: \(error.localizedDescription)"
            }
        }
    }

    private func processNuggets() {
        guard canProcess else { return }

        isProcessing = true

        Task {
            do {
                try await PreferencesService.shared.processNuggets(nuggetIds: nil)
                await MainActor.run {
                    isProcessing = false
                    showProcessSuccess = true
                }
                // Wait a bit then reload
                try await Task.sleep(nanoseconds: 2_000_000_000)
                loadNuggets()
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to process nuggets: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteNuggets(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let nugget = filteredNuggets[index]
                do {
                    try await NuggetService.shared.deleteNugget(nuggetId: nugget.nuggetId)
                    await MainActor.run {
                        if let originalIndex = nuggets.firstIndex(where: { $0.nuggetId == nugget.nuggetId }) {
                            nuggets.remove(at: originalIndex)
                        }
                    }
                } catch {
                    print("Failed to delete nugget: \(error)")
                }
            }
        }
    }

    private func checkForSharedContentAsync() async {
        // Check for pending shared nuggets asynchronously
    }

    private func loadNuggetsIfNeeded() async {
        // Check if we should skip loading
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)

        // Skip if we've loaded recently (within 3 seconds) and have data
        if hasInitiallyLoaded && !nuggets.isEmpty && timeSinceLastRefresh < 3.0 {
            return
        }

        // Load if we haven't initially loaded or if nuggets is empty
        if !hasInitiallyLoaded || nuggets.isEmpty {
            await loadNuggetsAsync()
            hasInitiallyLoaded = true
        }
    }

    @MainActor
    private func loadNuggetsAsync() async {
        // Prevent duplicate concurrent loads
        guard !isLoading else { return }

        // Only show loading if we have no data yet
        if nuggets.isEmpty {
            isLoading = true
        }
        errorMessage = nil

        do {
            // First process shared content only if we haven't loaded recently
            let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
            let hadPendingNuggets = timeSinceLastRefresh > 3.0 ?
                try await NuggetService.shared.processPendingSharedNuggets() : false

            // Then load nuggets
            let loadedNuggets = try await NuggetService.shared.listNuggets()

            withAnimation(.easeInOut(duration: 0.2)) {
                nuggets = loadedNuggets
                isLoading = false
                lastRefreshTime = Date()
            }

            // If we had pending nuggets, also trigger a refresh in HomeView
            if hadPendingNuggets {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshNuggets"), object: nil)
            }
        } catch {
            errorMessage = "Failed to load nuggets: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

struct NuggetDetailView: View {
    let nugget: Nugget

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let title = nugget.title {
                    Text(title)
                        .font(.title2.bold())
                }

                if let summary = nugget.summary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(summary)
                    }
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 12))
                }

                if let keyPoints = nugget.keyPoints, !keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Key Points")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        ForEach(keyPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.secondary)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                Text(point)
                            }
                        }
                    }
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 12))
                }

                if let question = nugget.question {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reflect")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(question)
                            .italic()
                    }
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Source")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    if let url = URL(string: nugget.sourceUrl) {
                        Link(nugget.sourceUrl, destination: url)
                            .font(.caption)
                    } else {
                        Text(nugget.sourceUrl)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .navigationTitle("Nugget")
    }
}

#Preview {
    InboxView()
}

struct NuggetRowView: View {
    let nugget: Nugget
    @State private var isVisible = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Gold category dot
            GoldCategoryDot()
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                // Title or URL
                if let title = nugget.title {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                        .transition(.opacity)
                } else {
                    Text(nugget.sourceUrl)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }

                // Summary or status
                if let summary = nugget.summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.goldAccent)
                        Text("Ready to process")
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                }

                // Bottom row with category and time
                HStack {
                    // Category badge with gold accent
                    if let category = nugget.category {
                        HStack(spacing: 4) {
                            Text(SparkSymbol.spark)
                                .font(.system(size: 10))
                                .foregroundColor(.goldAccent)
                            Text(category.capitalized)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.goldAccent.opacity(0.15),
                                    Color.goldAccent.opacity(0.05)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.goldAccent.opacity(0.3), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Processing indicator if being processed
                    if nugget.summary == nil && nugget.title != nil {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Processing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }

                    Spacer()

                    // Time ago
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(timeAgo(from: nugget.createdAt))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).delay(0.05)) {
                isVisible = true
            }
        }
    }

    private func getCategoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "business": return .green
        case "sport": return .red
        case "technology": return .blue
        case "career": return .purple
        case "health": return .pink
        case "science": return .indigo
        case "entertainment": return .orange
        case "politics": return .brown
        case "education": return .teal
        default: return .gray
        }
    }

    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let components = calendar.dateComponents([.hour, .minute], from: date, to: now)
            if let hours = components.hour, hours > 0 {
                return "\(hours)h ago"
            } else if let minutes = components.minute, minutes > 0 {
                return "\(minutes)m ago"
            } else {
                return "Just now \(SparkSymbol.spark)"
            }
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let components = calendar.dateComponents([.day], from: date, to: now)
            if let days = components.day, days < 7 {
                return "\(days)d ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        }
    }
}

struct ProcessBanner: View {
    let count: Int
    let isProcessing: Bool
    let canProcess: Bool
    let onProcess: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count) nugget\(count == 1 ? "" : "s") ready to process")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if !canProcess {
                    Text("Add at least 2 items to process")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("Uses AI to create learning nuggets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Group {
                if canProcess && !isProcessing {
                    Button {
                        onProcess()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                            Text("Process")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(GlassProminentButtonStyle())
                } else {
                    Button {
                        onProcess()
                    } label: {
                        HStack(spacing: 6) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                Text("Process")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .disabled(true)
                    .buttonStyle(GlassButtonStyle())
                }
            }
        }
        .padding()
        .glassEffect(
            canProcess ? .regular : .regular.tint(.orange),
            in: .rect
        )
    }
}

struct AddNuggetView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (Nugget) -> Void

    @State private var selectedTab = 0
    @State private var url = ""
    @State private var title = ""
    @State private var category = ""
    @State private var selectedRSSFeed: RSSFeed?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private func detectSourceType(from url: String) -> String {
        let urlLower = url.lowercased()

        if urlLower.contains("linkedin.com/posts/") ||
           urlLower.contains("linkedin.com/pulse/") ||
           urlLower.contains("linkedin.com/feed/") {
            return "linkedin"
        }

        if urlLower.contains("twitter.com/") || urlLower.contains("x.com/") {
            return "tweet"
        }

        if urlLower.contains("youtube.com/") || urlLower.contains("youtu.be/") {
            return "youtube"
        }

        return "url"
    }

    private var sourceTypeIcon: String {
        let sourceType = detectSourceType(from: url)
        switch sourceType {
        case "linkedin":
            return "link.circle.fill"
        case "tweet":
            return "at.circle.fill"
        case "youtube":
            return "play.rectangle.fill"
        default:
            return "globe"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom segmented control
                HStack(spacing: 0) {
                    Button {
                        selectedTab = 0
                    } label: {
                        HStack {
                            Image(systemName: "link")
                                .font(.subheadline)
                            Text("URL")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassEffect(
                            selectedTab == 0 ? .regular : .clear,
                            in: .rect(cornerRadius: 10)
                        )
                    }
                    .foregroundColor(selectedTab == 0 ? .primary : .secondary)

                    Button {
                        selectedTab = 1
                    } label: {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.subheadline)
                            Text("RSS Feed")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassEffect(
                            selectedTab == 1 ? .regular : .clear,
                            in: .rect(cornerRadius: 10)
                        )
                    }
                    .foregroundColor(selectedTab == 1 ? .primary : .secondary)
                }
                .padding()
                .glassEffect(in: .rect)

                TabView(selection: $selectedTab) {
                    urlInputView
                        .tag(0)

                    rssFeedView
                        .tag(1)
                }
                #if !os(macOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
            }
            .navigationTitle("Save to Feed")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var urlInputView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Paste a URL")
                        .font(.headline)

                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            TextField("https://example.com/article", text: $url)
                                .textFieldStyle(.plain)

                            if !url.isEmpty {
                                Image(systemName: sourceTypeIcon)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 12))
                        #if !os(macOS)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        #endif

                        // Show notice for Twitter/X URLs
                        if detectSourceType(from: url) == "tweet" {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Twitter/X Not Supported")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.orange)
                                    Spacer()
                                }
                                Text("Due to Twitter/X's restrictions, we cannot extract content from tweets. Please save articles from other sources instead.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                            .glassEffect(.regular.tint(.orange), in: .rect(cornerRadius: 10))
                        }

                        TextField("Title (optional)", text: $title)
                            .textFieldStyle(.plain)
                            .padding()
                            .glassEffect(in: .rect(cornerRadius: 12))

                        TextField("Category (optional)", text: $category)
                            .textFieldStyle(.plain)
                            .padding()
                            .glassEffect(in: .rect(cornerRadius: 12))
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .glassEffect(.regular.tint(.red), in: .rect(cornerRadius: 10))
                }

                Button {
                    saveNugget()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                        } else {
                            if detectSourceType(from: url) == "tweet" {
                                Image(systemName: "xmark.circle.fill")
                                Text("Twitter/X Not Supported")
                                    .fontWeight(.semibold)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Add to Feed")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassProminentButtonStyle())
                .disabled(url.isEmpty || isSaving || detectSourceType(from: url) == "tweet")
            }
            .padding()
        }
    }

    private var rssFeedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Popular RSS Feeds")
                    .font(.headline)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    ForEach(RSSFeed.popularFeeds) { feed in
                        Button {
                            selectedRSSFeed = feed
                            saveRSSFeed(feed)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: feed.icon)
                                    .font(.title2)
                                    .foregroundColor(.primary)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(feed.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text(feed.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if isSaving && selectedRSSFeed?.id == feed.id {
                                    ProgressView()
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding()
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                        }
                        .disabled(isSaving)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private func saveNugget() {
        isSaving = true
        errorMessage = nil

        let sourceType = detectSourceType(from: url)

        let request = CreateNuggetRequest(
            sourceUrl: url,
            sourceType: sourceType,
            rawTitle: title.isEmpty ? nil : title,
            rawText: nil,
            category: category.isEmpty ? nil : category
        )

        Task {
            do {
                let nugget = try await NuggetService.shared.createNugget(request: request)
                await MainActor.run {
                    onSave(nugget)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }

    private func saveRSSFeed(_ feed: RSSFeed) {
        isSaving = true
        errorMessage = nil

        let request = CreateNuggetRequest(
            sourceUrl: feed.url,
            sourceType: "url",
            rawTitle: feed.name,
            rawText: nil,
            category: feed.category
        )

        Task {
            do {
                let nugget = try await NuggetService.shared.createNugget(request: request)
                await MainActor.run {
                    onSave(nugget)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    isSaving = false
                    selectedRSSFeed = nil
                }
            }
        }
    }
}

struct RSSFeed: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let description: String
    let category: String
    let icon: String

    static let popularFeeds: [RSSFeed] = [
        RSSFeed(name: "BBC News", url: "https://feeds.bbci.co.uk/news/rss.xml", description: "Latest world news", category: "news", icon: "globe"),
        RSSFeed(name: "BBC Technology", url: "https://feeds.bbci.co.uk/news/technology/rss.xml", description: "Tech news and analysis", category: "technology", icon: "cpu"),
        RSSFeed(name: "BBC Business", url: "https://feeds.bbci.co.uk/news/business/rss.xml", description: "Business and finance news", category: "business", icon: "chart.line.uptrend.xyaxis"),
        RSSFeed(name: "BBC Science", url: "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml", description: "Science & environment", category: "science", icon: "flask"),
        RSSFeed(name: "BBC Health", url: "https://feeds.bbci.co.uk/news/health/rss.xml", description: "Health news", category: "health", icon: "heart"),
        RSSFeed(name: "BBC Sport", url: "https://feeds.bbci.co.uk/sport/rss.xml", description: "Sports news", category: "sport", icon: "figure.run")
    ]
}
