import SwiftUI

struct ArticleToOpen: Identifiable {
    let id = UUID()
    let url: URL
    let title: String?
}

struct SessionView: View {
    let session: Session
    @Environment(\.dismiss) var dismiss
    @State private var currentCardIndex = 0
    @State private var completedNuggetIds: [String] = []
    @State private var isCompleting = false
    @State private var isProcessing = false
    @State private var processedSession: Session?
    @State private var pollingTimer: Timer?

    // Use the processed session if available, otherwise use original
    var currentSession: Session {
        processedSession ?? session
    }

    // Convert session nuggets into individual swipeable cards
    var cards: [CardData] {
        var result: [CardData] = []

        // Only show ready nuggets
        let readyNuggets = currentSession.nuggets.filter { $0.isReady }

        for nugget in readyNuggets {
            // Check if this is a grouped nugget with individual summaries (digest)
            if let individualSummaries = nugget.individualSummaries, !individualSummaries.isEmpty {
                // Card 1: Overview showing the combined summary
                result.append(CardData(
                    nuggetId: nugget.nuggetId,
                    cardType: .groupOverview,
                    nugget: nugget
                ))

                // Cards 2+: Individual article cards
                for (index, summary) in individualSummaries.enumerated() {
                    result.append(CardData(
                        nuggetId: nugget.nuggetId,
                        cardType: .individualArticle(summary: summary, index: index, total: individualSummaries.count),
                        nugget: nugget
                    ))
                }
            } else {
                // Single nugget - just one card
                result.append(CardData(
                    nuggetId: nugget.nuggetId,
                    cardType: .single,
                    nugget: nugget
                ))
            }
        }

        return result
    }

    var body: some View {
        ZStack {
            if currentCardIndex < cards.count {
                CardStackView(
                    cards: Array(cards[currentCardIndex...]),
                    onNext: handleNextCard,
                    onSkip: handleSkip,
                    onBack: handleBack,
                    onClose: { completeSession() }
                )
            } else {
                sessionCompleteView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            startPollingIfNeeded()
        }
        .onDisappear {
            stopPolling()
        }
    }

    private var sessionCompleteView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                // Spark pulse animation layer
                SparkPulse()
                    .position(x: UIScreen.main.bounds.width / 2, y: 40)

                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.primary)

                    Text("Session Complete \(SparkSymbol.spark)")
                        .font(.title.bold())

                    Text("You reviewed \(completedNuggetIds.count) nugget\(completedNuggetIds.count == 1 ? "" : "s")")
                        .foregroundColor(.secondary)
                }
                .padding(40)
                .glassEffect(in: .rect(cornerRadius: 24))
            }

            Spacer()

            Button {
                HapticFeedback.success()
                completeSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                    Text("Done")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(GlassProminentButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .onAppear {
            HapticFeedback.success()
        }
    }

    private func handleNextCard() {
        // Track nugget completion
        if currentCardIndex < cards.count {
            let nuggetId = cards[currentCardIndex].nuggetId
            if !completedNuggetIds.contains(nuggetId) {
                completedNuggetIds.append(nuggetId)
                // Haptic feedback for nugget completion
                HapticFeedback.medium()
            }
        }
        currentCardIndex += 1
    }

    private func handleSkip() {
        HapticFeedback.selection()
        currentCardIndex += 1
    }

    private func handleBack() {
        if currentCardIndex > 0 {
            HapticFeedback.selection()
            currentCardIndex -= 1
        }
    }

    private func completeSession() {
        isCompleting = true

        Task {
            do {
                if let sessionId = session.sessionId {
                    // Use the session-based completion
                    _ = try await NuggetService.shared.completeSession(
                        sessionId: sessionId,
                        completedNuggetIds: completedNuggetIds
                    )
                } else if !completedNuggetIds.isEmpty {
                    // No session ID - mark all completed nuggets as read directly
                    try await NuggetService.shared.markNuggetsRead(nuggetIds: completedNuggetIds)
                }

                await MainActor.run {
                    // Success haptic on session completion
                    HapticFeedback.success()

                    // Dismiss first, then notify to refresh after a short delay
                    // This ensures the view hierarchy is stable
                    dismiss()

                    // Notify HomeView to refresh nuggets after dismissal
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshNuggets"), object: nil)
                    }
                }
            } catch {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }

    private func startPollingIfNeeded() {
        // Check if any nuggets are still processing
        let hasProcessing = currentSession.nuggets.contains { nugget in
            if let individualSummaries = nugget.individualSummaries {
                return individualSummaries.contains { $0.summary == "Processing..." }
            }
            return nugget.summary == "Processing..." ||
                   nugget.summary?.contains("Processing") == true
        }

        if hasProcessing && session.sessionId != nil {
            isProcessing = true
            startPolling()
        }
    }

    private func startPolling() {
        guard let sessionId = session.sessionId else { return }

        // Poll every 2 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task {
                await checkSessionStatus(sessionId: sessionId)
            }
        }

        // Also check immediately
        Task {
            await checkSessionStatus(sessionId: sessionId)
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isProcessing = false
    }

    private func checkSessionStatus(sessionId: String) async {
        guard let url = URL(string: "\(APIConfig.baseURL)/sessions/\(sessionId)/status") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add auth header
        if let token = KeychainManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            struct SessionStatusResponse: Codable {
                let sessionId: String
                let nuggets: [Nugget]
                let processingComplete: Bool?
            }

            let response = try decoder.decode(SessionStatusResponse.self, from: data)

            await MainActor.run {
                // Update the session with new data
                processedSession = Session(
                    sessionId: response.sessionId,
                    nuggets: response.nuggets,
                    message: nil
                )

                // Stop polling if processing is complete
                if response.processingComplete == true {
                    stopPolling()
                }
            }
        } catch {
            print("Error checking session status: \(error)")
        }
    }
}

// MARK: - Card Data Models

struct CardData: Identifiable {
    let id = UUID()
    let nuggetId: String
    let cardType: CardType
    let nugget: Nugget

    enum CardType {
        case single
        case groupOverview
        case individualArticle(summary: IndividualSummary, index: Int, total: Int)
    }
}

// MARK: - Card Stack View

struct CardStackView: View {
    let cards: [CardData]
    let onNext: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void
    let onClose: () -> Void

    @State private var offset = CGSize.zero
    @State private var selectedArticle: ArticleToOpen?
    @State private var verticalOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background cards for depth effect
                if cards.count > 2 {
                    cardView(for: cards[2], geometry: geometry, showCloseButton: false)
                        .scaleEffect(0.90)
                        .offset(y: 16)
                        .opacity(0.3)
                }

                if cards.count > 1 {
                    cardView(for: cards[1], geometry: geometry, showCloseButton: false)
                        .scaleEffect(0.95)
                        .offset(y: 8)
                        .opacity(0.6)
                }

                // Top card (current)
                if let currentCard = cards.first {
                    cardView(for: currentCard, geometry: geometry, showCloseButton: true)
                        .offset(x: offset.width, y: verticalOffset)
                        .rotationEffect(.degrees(Double(offset.width / 30)))
                        .scaleEffect(verticalOffset > 0 ? max(0.9, 1 - verticalOffset / 1000) : 1)
                        .opacity(verticalOffset > 0 ? max(0.5, 1 - verticalOffset / 400) : 1)
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 20)
                                .onChanged { gesture in
                                    let horizontalMovement = abs(gesture.translation.width)
                                    let verticalMovement = abs(gesture.translation.height)

                                    // Check if this is a downward swipe (positive height means down)
                                    if verticalMovement > horizontalMovement * 1.5 && gesture.translation.height > 0 {
                                        // Vertical swipe down - track for dismiss
                                        verticalOffset = gesture.translation.height
                                    } else if horizontalMovement > verticalMovement * 1.5 {
                                        // Horizontal swipe - allow card to move
                                        offset = CGSize(width: gesture.translation.width, height: 0)
                                    }
                                }
                                .onEnded { gesture in
                                    let horizontalMovement = abs(gesture.translation.width)
                                    let verticalMovement = abs(gesture.translation.height)

                                    // Check for swipe down to dismiss
                                    if verticalMovement > horizontalMovement * 1.5 && gesture.translation.height > 150 {
                                        // Swipe down - dismiss
                                        handleSwipe(direction: .down)
                                    }
                                    // Only trigger horizontal swipe if horizontal movement dominates
                                    else if horizontalMovement > verticalMovement * 1.5 && horizontalMovement > 120 {
                                        // Swipe left (negative width) = next card (like turning page forward)
                                        // Swipe right (positive width) = previous card (like turning page back)
                                        handleSwipe(direction: gesture.translation.width > 0 ? .right : .left)
                                    } else {
                                        // Reset card position
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            offset = .zero
                                            verticalOffset = 0
                                        }
                                    }
                                }
                        )
                        .overlay(swipeIndicators)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        #if os(macOS)
        .sheet(item: $selectedArticle) { article in
            ArticleWebView(url: article.url, title: article.title)
                .onAppear {
                    print("🎬 sheet: ArticleWebView appeared with URL: \(article.url.absoluteString)")
                }
        }
        #else
        .fullScreenCover(item: $selectedArticle) { article in
            ArticleWebView(url: article.url, title: article.title)
                .onAppear {
                    print("🎬 fullScreenCover: ArticleWebView appeared with URL: \(article.url.absoluteString)")
                }
        }
        #endif
    }

    @ViewBuilder
    private func cardView(for card: CardData, geometry: GeometryProxy, showCloseButton: Bool) -> some View {
        switch card.cardType {
        case .single, .groupOverview:
            OverviewCard(
                nugget: card.nugget,
                geometry: geometry,
                showCloseButton: showCloseButton,
                onOpenArticle: { url, title in
                    print("🔗 SessionView: Opening article - URL: \(url.absoluteString)")
                    print("🔗 SessionView: Title: \(title ?? "nil")")
                    selectedArticle = ArticleToOpen(url: url, title: title)
                    print("🔗 SessionView: selectedArticle set to \(selectedArticle?.id.uuidString ?? "nil")")
                },
                onClose: onClose
            )
            .id("overview-\(card.nuggetId)") // Reset scroll position when card changes

        case .individualArticle(let summary, let index, let total):
            IndividualArticleCard(
                summary: summary,
                index: index + 1,
                total: total,
                geometry: geometry,
                showCloseButton: showCloseButton,
                nuggetId: card.nuggetId,
                onOpenArticle: { url, title in
                    print("🔗 SessionView (Individual): Opening article - URL: \(url.absoluteString)")
                    print("🔗 SessionView (Individual): Title: \(title ?? "nil")")
                    selectedArticle = ArticleToOpen(url: url, title: title)
                    print("🔗 SessionView (Individual): selectedArticle set to \(selectedArticle?.id.uuidString ?? "nil")")
                },
                onClose: onClose
            )
            .id("article-\(card.nuggetId)-\(index)") // Reset scroll position when card changes
        }
    }

    private var swipeIndicators: some View {
        ZStack {
            // Swipe left (negative offset) = NEXT (like turning page forward)
            if offset.width < -50 {
                HStack {
                    VStack {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.primary)
                        Text("NEXT")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(40)
                    .opacity(Double(-offset.width / 120))
                    Spacer()
                }
            }
            // Swipe right (positive offset) = BACK (like turning page back)
            else if offset.width > 50 {
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("BACK")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                    .opacity(Double(offset.width / 120))
                }
            }
            // Swipe down = EXIT
            if verticalOffset > 50 {
                VStack {
                    VStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("EXIT")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                    .opacity(Double(verticalOffset / 150))
                    Spacer()
                }
                .padding(.top, 60)
            }
        }
    }

    private func handleSwipe(direction: SwipeDirection) {
        // Haptic feedback for swipe actions
        HapticFeedback.light()

        if direction == .down {
            // Swipe down - animate card off screen and dismiss
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                verticalOffset = 1000
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onClose()
                verticalOffset = 0
            }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                offset = CGSize(width: direction == .right ? 1000 : -1000, height: 0)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Swipe left (like turning page forward) = next card
                // Swipe right (like turning page back) = go back
                if direction == .left {
                    onNext()
                } else {
                    onBack()
                }
                offset = .zero
            }
        }
    }

    enum SwipeDirection {
        case left, right, down
    }
}

// MARK: - Overview Card

struct OverviewCard: View {
    let nugget: Nugget
    let geometry: GeometryProxy
    let showCloseButton: Bool
    let onOpenArticle: (URL, String?) -> Void
    let onClose: () -> Void

    @State private var isSharing = false
    @State private var showShareSheet = false
    @State private var shareUrl: URL?
    @State private var showShareToFriends = false

    var sourceCount: Int {
        nugget.sourceUrls?.count ?? 1
    }

    var isGrouped: Bool {
        nugget.isGrouped == true && sourceCount > 1
    }

    var displayTitle: String {
        if isGrouped, let individualSummaries = nugget.individualSummaries, !individualSummaries.isEmpty {
            // For grouped nuggets, combine the first 2 article titles
            let titles = individualSummaries.prefix(2).map { $0.title }
            if titles.count == 2 {
                return "\(titles[0]) & \(titles[1])"
            } else if titles.count == 1 {
                return titles[0]
            }
        }
        return nugget.title ?? "Nugget"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        // Invisible anchor at top for scroll reset
                        Color.clear.frame(height: 0).id("scrollTop-\(nugget.nuggetId)")

                        // Category badge
                        if let category = nugget.category {
                            HStack {
                                Text(category.uppercased())
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary.opacity(0.6))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                                Spacer()
                            }
                            .padding(.trailing, 44) // Make room for close button
                        }

                    // Title
                    Text(displayTitle)
                        .font(.system(size: 28, weight: .bold))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider().opacity(0.3)

                    // For grouped nuggets, show "Content in this nugget" with headlines
                    if isGrouped, let individualSummaries = nugget.individualSummaries {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Content in this nugget", systemImage: "doc.on.doc.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary.opacity(0.7))

                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(Array(individualSummaries.enumerated()), id: \.offset) { index, summary in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(summary.title)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if let host = URL(string: summary.sourceUrl)?.host {
                                            Text(host)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                                }
                            }
                        }
                    } else {
                        // For single nuggets, show summary
                        if let summary = nugget.summary {
                            Text(summary)
                                .font(.body)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundColor(.primary.opacity(0.9))
                        }

                        // Key Points
                        if let keyPoints = nugget.keyPoints, !keyPoints.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Key Insights \(SparkSymbol.spark)", systemImage: "lightbulb.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary.opacity(0.7))

                                ForEach(Array(keyPoints.enumerated()), id: \.offset) { index, point in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(SparkSymbol.spark)
                                            .font(.caption)
                                            .foregroundColor(.goldAccent)
                                            .padding(.top, 4)

                                        Text(point)
                                            .font(.subheadline)
                                            .lineSpacing(4)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                        }

                        // Question
                        if let question = nugget.question {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Reflect", systemImage: "bubble.left.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary.opacity(0.7))

                                Text(question)
                                    .font(.subheadline)
                                    .italic()
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .foregroundColor(.primary.opacity(0.8))
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                        }
                    }
                }
                    .padding(28)
                    .padding(.top, 8) // Extra top padding for close button area
                }

                // Bottom hint - compact version with icons
                HStack(spacing: 8) {
                    if sourceCount > 1 {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(sourceCount) sources")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    Image(systemName: "hand.draw.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Swipe to continue")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture {
                if let url = URL(string: nugget.sourceUrl) {
                    onOpenArticle(url, nugget.title)
                }
            }
            .background(RoundedRectangle(cornerRadius: 32).fill(.ultraThinMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.primary.opacity(0.15), Color.primary.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 30, x: 0, y: 15)
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)

            // Close button - fixed in top right corner
            if showCloseButton {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .padding(20)
            }

            // Share buttons - fixed in bottom right corner
            if showCloseButton {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Spacer()
                        // Share to Friends button
                        Button {
                            showShareToFriends = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Friends")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.ultraThinMaterial))
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                        }

                        // Share link button
                        Button {
                            shareNugget()
                        } label: {
                            HStack(spacing: 6) {
                                if isSharing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text("Share")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.ultraThinMaterial))
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                        }
                        .disabled(isSharing)
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareUrl {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showShareToFriends) {
            ShareToFriendsSheet(nuggetId: nugget.nuggetId, nuggetTitle: nugget.title)
        }
    }

    private func shareNugget() {
        isSharing = true

        Task {
            do {
                let response = try await NuggetService.shared.shareNugget(nuggetId: nugget.nuggetId)
                await MainActor.run {
                    isSharing = false
                    if let url = URL(string: response.shareUrl) {
                        shareUrl = url
                        showShareSheet = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSharing = false
                    print("Error sharing nugget: \(error)")
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Individual Article Card

struct IndividualArticleCard: View {
    let summary: IndividualSummary
    let index: Int
    let total: Int
    let geometry: GeometryProxy
    let showCloseButton: Bool
    let nuggetId: String
    let onOpenArticle: (URL, String?) -> Void
    let onClose: () -> Void

    @State private var isSharing = false
    @State private var showShareSheet = false
    @State private var shareUrl: URL?
    @State private var showShareToFriends = false

    var urlHost: String {
        URL(string: summary.sourceUrl)?.host ?? summary.sourceUrl
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        // Article indicator
                        HStack {
                            Text("Article \(index) of \(total)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Spacer()
                        }
                        .padding(.trailing, 44) // Make room for close button

                    // Title
                    if !summary.title.isEmpty {
                        Text(summary.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Summary
                    if !summary.summary.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Summary", systemImage: "doc.text.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary.opacity(0.7))

                            Text(summary.summary)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineSpacing(6)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                    }

                    // Key Points
                    if !summary.keyPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Key Points", systemImage: "list.bullet.circle.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary.opacity(0.7))

                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(summary.keyPoints.enumerated()), id: \.offset) { idx, point in
                                    HStack(alignment: .top, spacing: 12) {
                                        Circle()
                                            .fill(Color.secondary)
                                            .frame(width: 8, height: 8)
                                            .padding(.top, 6)

                                        Text(point)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .lineSpacing(4)
                                    }
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }

                    // Source URL
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Source", systemImage: "link.circle.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Text(urlHost)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5))
                    }
                    .padding(28)
                    .padding(.top, 8) // Extra top padding for close button area
                }

                // Bottom hint - compact version with icons
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Tap to open")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))
                    Image(systemName: "hand.draw.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(index == total ? "Swipe to complete" : "Swipe for next")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture {
                if let url = URL(string: summary.sourceUrl) {
                    onOpenArticle(url, summary.title)
                }
            }
            .background(RoundedRectangle(cornerRadius: 32).fill(.ultraThinMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.primary.opacity(0.15), Color.primary.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 30, x: 0, y: 15)
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)

            // Close button - fixed in top right corner
            if showCloseButton {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .padding(20)
            }

            // Share buttons - fixed in bottom right corner
            if showCloseButton {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Spacer()
                        // Share to Friends button
                        Button {
                            showShareToFriends = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Friends")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.ultraThinMaterial))
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                        }

                        // Share link button
                        Button {
                            shareNugget()
                        } label: {
                            HStack(spacing: 6) {
                                if isSharing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text("Share")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.ultraThinMaterial))
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                        }
                        .disabled(isSharing)
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareUrl {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showShareToFriends) {
            ShareToFriendsSheet(nuggetId: nuggetId, nuggetTitle: summary.title)
        }
    }

    private func shareNugget() {
        isSharing = true

        Task {
            do {
                let response = try await NuggetService.shared.shareNugget(nuggetId: nuggetId)
                await MainActor.run {
                    isSharing = false
                    if let url = URL(string: response.shareUrl) {
                        shareUrl = url
                        showShareSheet = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSharing = false
                    print("Error sharing nugget: \(error)")
                }
            }
        }
    }
}
