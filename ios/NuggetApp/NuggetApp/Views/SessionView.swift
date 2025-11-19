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

    // Convert session nuggets into individual swipeable cards
    var cards: [CardData] {
        var result: [CardData] = []

        for nugget in session.nuggets {
            // Check if this is a grouped nugget with multiple sources
            if let isGrouped = nugget.isGrouped, isGrouped,
               let sourceUrls = nugget.sourceUrls,
               let individualSummaries = nugget.individualSummaries,
               sourceUrls.count > 1 {

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
                    onBack: handleBack
                )
            } else {
                sessionCompleteView
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Exit") {
                    completeSession()
                }
            }
        }
    }

    private var sessionCompleteView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)

                Text("Session Complete!")
                    .font(.title.bold())

                Text("You reviewed \(completedNuggetIds.count) nugget\(completedNuggetIds.count == 1 ? "" : "s")")
                    .foregroundColor(.secondary)
            }
            .padding(40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))

            Spacer()

            Button {
                completeSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                    Text("Done")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundColor(.white)
                .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }

    private func handleNextCard() {
        // Track nugget completion
        if currentCardIndex < cards.count {
            let nuggetId = cards[currentCardIndex].nuggetId
            if !completedNuggetIds.contains(nuggetId) {
                completedNuggetIds.append(nuggetId)
            }
        }
        currentCardIndex += 1
    }

    private func handleSkip() {
        currentCardIndex += 1
    }

    private func handleBack() {
        if currentCardIndex > 0 {
            currentCardIndex -= 1
        }
    }

    private func completeSession() {
        guard let sessionId = session.sessionId else {
            dismiss()
            return
        }

        isCompleting = true

        Task {
            do {
                _ = try await NuggetService.shared.completeSession(
                    sessionId: sessionId,
                    completedNuggetIds: completedNuggetIds
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    dismiss()
                }
            }
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

    @State private var offset = CGSize.zero
    @State private var selectedArticle: ArticleToOpen?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background cards for depth effect
                if cards.count > 2 {
                    cardView(for: cards[2], geometry: geometry)
                        .scaleEffect(0.90)
                        .offset(y: 16)
                        .opacity(0.3)
                }

                if cards.count > 1 {
                    cardView(for: cards[1], geometry: geometry)
                        .scaleEffect(0.95)
                        .offset(y: 8)
                        .opacity(0.6)
                }

                // Top card (current)
                if let currentCard = cards.first {
                    cardView(for: currentCard, geometry: geometry)
                        .offset(offset)
                        .rotationEffect(.degrees(Double(offset.width / 30)))
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 20)
                                .onChanged { gesture in
                                    // Only track horizontal movement if it's more significant than vertical
                                    let horizontalMovement = abs(gesture.translation.width)
                                    let verticalMovement = abs(gesture.translation.height)

                                    if horizontalMovement > verticalMovement * 1.5 {
                                        // Horizontal swipe - allow card to move
                                        offset = CGSize(width: gesture.translation.width, height: 0)
                                    }
                                }
                                .onEnded { gesture in
                                    let horizontalMovement = abs(gesture.translation.width)
                                    let verticalMovement = abs(gesture.translation.height)

                                    // Only trigger swipe if horizontal movement dominates
                                    if horizontalMovement > verticalMovement * 1.5 && horizontalMovement > 120 {
                                        // Swipe left (negative width) = next card (like turning page forward)
                                        // Swipe right (positive width) = previous card (like turning page back)
                                        handleSwipe(direction: gesture.translation.width > 0 ? .right : .left)
                                    } else {
                                        // Reset card position
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .overlay(swipeIndicators)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
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
    private func cardView(for card: CardData, geometry: GeometryProxy) -> some View {
        switch card.cardType {
        case .single, .groupOverview:
            OverviewCard(
                nugget: card.nugget,
                geometry: geometry,
                onOpenArticle: { url, title in
                    print("🔗 SessionView: Opening article - URL: \(url.absoluteString)")
                    print("🔗 SessionView: Title: \(title ?? "nil")")
                    selectedArticle = ArticleToOpen(url: url, title: title)
                    print("🔗 SessionView: selectedArticle set to \(selectedArticle?.id.uuidString ?? "nil")")
                }
            )

        case .individualArticle(let summary, let index, let total):
            IndividualArticleCard(
                summary: summary,
                index: index + 1,
                total: total,
                geometry: geometry,
                onOpenArticle: { url, title in
                    print("🔗 SessionView (Individual): Opening article - URL: \(url.absoluteString)")
                    print("🔗 SessionView (Individual): Title: \(title ?? "nil")")
                    selectedArticle = ArticleToOpen(url: url, title: title)
                    print("🔗 SessionView (Individual): selectedArticle set to \(selectedArticle?.id.uuidString ?? "nil")")
                }
            )
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
                            .foregroundStyle(.green)
                        Text("NEXT")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
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
                            .foregroundStyle(.blue)
                        Text("BACK")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding(40)
                    .opacity(Double(offset.width / 120))
                }
            }
        }
    }

    private func handleSwipe(direction: SwipeDirection) {
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

    enum SwipeDirection {
        case left, right
    }
}

// MARK: - Overview Card

struct OverviewCard: View {
    let nugget: Nugget
    let geometry: GeometryProxy
    let onOpenArticle: (URL, String?) -> Void

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
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
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
                                Label("Key Insights", systemImage: "lightbulb.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary.opacity(0.7))

                                ForEach(Array(keyPoints.enumerated()), id: \.offset) { index, point in
                                    HStack(alignment: .top, spacing: 12) {
                                        Circle()
                                            .fill(LinearGradient(
                                                colors: [.blue, .cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 8)

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
            }

            // Bottom hint
            VStack(spacing: 12) {
                Divider().opacity(0.3)

                HStack(spacing: 16) {
                    if sourceCount > 1 {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.caption2)
                            Text("\(sourceCount) sources")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.primary.opacity(0.7))

                        Circle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "hand.draw.fill")
                            .font(.caption2)
                        Text("Swipe right for details")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
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
    }
}

// MARK: - Individual Article Card

struct IndividualArticleCard: View {
    let summary: IndividualSummary
    let index: Int
    let total: Int
    let geometry: GeometryProxy
    let onOpenArticle: (URL, String?) -> Void

    var urlHost: String {
        URL(string: summary.sourceUrl)?.host ?? summary.sourceUrl
    }

    var body: some View {
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
                                            .fill(LinearGradient(
                                                colors: [Color.blue, Color.purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
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
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
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
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.blue.opacity(0.2), lineWidth: 0.5))
                }
                .padding(28)
            }

            // Bottom hint
            VStack(spacing: 12) {
                Divider().opacity(0.3)

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption2)
                        Text("Tap to open")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 4, height: 4)

                    HStack(spacing: 6) {
                        Image(systemName: "hand.draw.fill")
                            .font(.caption2)
                        Text(index == total ? "Swipe to complete" : "Swipe for next")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
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
    }
}
