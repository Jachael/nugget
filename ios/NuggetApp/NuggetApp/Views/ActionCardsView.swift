import SwiftUI

// MARK: - Action Card Types

enum ActionCardType: Identifiable, Equatable {
    case addRSSFeeds
    case enableAutoProcessing
    case createDigest
    case upgradeForAutoProcessing
    case upgradeForRSS
    case upgradeForDigests
    case upgradeForMoreControl
    case catchUpYesterday(count: Int)
    case allCaughtUp

    var id: String {
        switch self {
        case .addRSSFeeds: return "addRSSFeeds"
        case .enableAutoProcessing: return "enableAutoProcessing"
        case .createDigest: return "createDigest"
        case .upgradeForAutoProcessing: return "upgradeForAutoProcessing"
        case .upgradeForRSS: return "upgradeForRSS"
        case .upgradeForDigests: return "upgradeForDigests"
        case .upgradeForMoreControl: return "upgradeForMoreControl"
        case .catchUpYesterday: return "catchUpYesterday"
        case .allCaughtUp: return "allCaughtUp"
        }
    }

    var isUpgradeCard: Bool {
        switch self {
        case .upgradeForAutoProcessing, .upgradeForRSS, .upgradeForDigests, .upgradeForMoreControl:
            return true
        default:
            return false
        }
    }
}

// MARK: - Action Card Data

struct ActionCardData {
    let type: ActionCardType
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let actionLabel: String?
    let destinationTier: String? // "pro" or "ultimate"

    var isUpgradeCard: Bool {
        type.isUpgradeCard
    }
}

// MARK: - Action Cards Manager

struct ActionCardsManager {
    let subscriptionTier: String // "free", "pro", "ultimate"
    let hasRSSFeeds: Bool
    let hasAutoProcessing: Bool
    let hasDigests: Bool
    let unreadYesterdayCount: Int
    let totalUnprocessedCount: Int

    /// Get prioritized action cards for the current user state
    func getActionCards(maxCards: Int = 2) -> [ActionCardData] {
        var cards: [ActionCardData] = []

        switch subscriptionTier {
        case "free":
            cards.append(contentsOf: getFreeUserCards())
        case "pro":
            cards.append(contentsOf: getProUserCards())
        case "ultimate":
            cards.append(contentsOf: getUltimateUserCards())
        default:
            cards.append(contentsOf: getFreeUserCards())
        }

        return Array(cards.prefix(maxCards))
    }

    private func getFreeUserCards() -> [ActionCardData] {
        var cards: [ActionCardData] = []

        // Primary: Encourage upgrade for auto-processing
        if totalUnprocessedCount > 0 {
            cards.append(ActionCardData(
                type: .upgradeForAutoProcessing,
                title: "Auto-process your content",
                subtitle: "Get AI summaries delivered 3x daily",
                icon: "sparkles",
                accentColor: .purple,
                actionLabel: "Upgrade to Pro",
                destinationTier: "pro"
            ))
        }

        // Secondary: Encourage RSS feeds (also needs upgrade)
        cards.append(ActionCardData(
            type: .upgradeForRSS,
            title: "Subscribe to RSS feeds",
            subtitle: "Get content from your favorite sources",
            icon: "antenna.radiowaves.left.and.right",
            accentColor: .orange,
            actionLabel: "Upgrade to Pro",
            destinationTier: "pro"
        ))

        return cards
    }

    private func getProUserCards() -> [ActionCardData] {
        var cards: [ActionCardData] = []

        // If they don't have RSS feeds set up, encourage that first
        if !hasRSSFeeds {
            cards.append(ActionCardData(
                type: .addRSSFeeds,
                title: "Subscribe to RSS feeds",
                subtitle: "Get content from your favorite sources",
                icon: "antenna.radiowaves.left.and.right",
                accentColor: .blue,
                actionLabel: "Add Feeds",
                destinationTier: nil
            ))
        }

        // If they have feeds but no auto-processing, encourage that
        if hasRSSFeeds && !hasAutoProcessing {
            cards.append(ActionCardData(
                type: .enableAutoProcessing,
                title: "Enable auto-processing",
                subtitle: "Get summaries delivered automatically",
                icon: "clock.arrow.2.circlepath",
                accentColor: .green,
                actionLabel: "Enable",
                destinationTier: nil
            ))
        }

        // Encourage upgrade to Ultimate for custom digests
        if hasRSSFeeds {
            cards.append(ActionCardData(
                type: .upgradeForDigests,
                title: "Create custom digests",
                subtitle: "Combine feeds into personalized summaries",
                icon: "square.stack.3d.up",
                accentColor: .purple,
                actionLabel: "Upgrade to Ultimate",
                destinationTier: "ultimate"
            ))
        }

        // If everything is set up, encourage more control
        if hasRSSFeeds && hasAutoProcessing {
            cards.append(ActionCardData(
                type: .upgradeForMoreControl,
                title: "Process every 2 hours",
                subtitle: "Get more frequent updates with Ultimate",
                icon: "gauge.with.dots.needle.67percent",
                accentColor: .indigo,
                actionLabel: "Upgrade",
                destinationTier: "ultimate"
            ))
        }

        return cards
    }

    private func getUltimateUserCards() -> [ActionCardData] {
        var cards: [ActionCardData] = []

        // If they don't have RSS feeds set up
        if !hasRSSFeeds {
            cards.append(ActionCardData(
                type: .addRSSFeeds,
                title: "Subscribe to RSS feeds",
                subtitle: "Get content from your favorite sources",
                icon: "antenna.radiowaves.left.and.right",
                accentColor: .blue,
                actionLabel: "Add Feeds",
                destinationTier: nil
            ))
        }

        // If they have feeds but no digests
        if hasRSSFeeds && !hasDigests {
            cards.append(ActionCardData(
                type: .createDigest,
                title: "Create a custom digest",
                subtitle: "Combine feeds into one summary",
                icon: "square.stack.3d.up",
                accentColor: .purple,
                actionLabel: "Create",
                destinationTier: nil
            ))
        }

        // If they have feeds but no auto-processing
        if hasRSSFeeds && !hasAutoProcessing {
            cards.append(ActionCardData(
                type: .enableAutoProcessing,
                title: "Enable auto-processing",
                subtitle: "Get summaries delivered automatically",
                icon: "clock.arrow.2.circlepath",
                accentColor: .green,
                actionLabel: "Enable",
                destinationTier: nil
            ))
        }

        // Catch up on yesterday if there's content
        if unreadYesterdayCount > 0 {
            cards.append(ActionCardData(
                type: .catchUpYesterday(count: unreadYesterdayCount),
                title: "Catch up on yesterday",
                subtitle: "\(unreadYesterdayCount) items waiting",
                icon: "clock.arrow.circlepath",
                accentColor: .orange,
                actionLabel: "Catch Up",
                destinationTier: nil
            ))
        }

        // If everything is set up and no content, show all caught up
        if cards.isEmpty && totalUnprocessedCount == 0 {
            cards.append(ActionCardData(
                type: .allCaughtUp,
                title: "You're all caught up!",
                subtitle: "Check back later for new content",
                icon: "checkmark.circle",
                accentColor: .green,
                actionLabel: nil,
                destinationTier: nil
            ))
        }

        return cards
    }
}

// MARK: - Action Card View

struct ActionCardView: View {
    let card: ActionCardData
    let onAction: () -> Void
    let onDismiss: (() -> Void)?

    @State private var isPressed = false

    var body: some View {
        Button(action: onAction) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(card.accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: card.icon)
                        .font(.system(size: 18))
                        .foregroundColor(card.accentColor)
                }

                // Text content
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(card.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Action button or chevron
                if let actionLabel = card.actionLabel {
                    if card.isUpgradeCard {
                        Text(actionLabel)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [card.accentColor, card.accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                    } else {
                        Text(actionLabel)
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(12)
                    }
                } else if card.type != .allCaughtUp {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Dismiss button for upgrade cards
                if card.isUpgradeCard, let onDismiss = onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .glassEffect(in: .rect(cornerRadius: 16))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(card.type == .allCaughtUp)
    }
}

// MARK: - Action Cards Stack

struct ActionCardsStack: View {
    let cards: [ActionCardData]
    let onCardAction: (ActionCardType) -> Void
    let onDismissCard: ((ActionCardType) -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(cards, id: \.type.id) { card in
                ActionCardView(
                    card: card,
                    onAction: { onCardAction(card.type) },
                    onDismiss: card.isUpgradeCard ? { onDismissCard?(card.type) } : nil
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Free user cards
        ActionCardsStack(
            cards: ActionCardsManager(
                subscriptionTier: "free",
                hasRSSFeeds: false,
                hasAutoProcessing: false,
                hasDigests: false,
                unreadYesterdayCount: 5,
                totalUnprocessedCount: 10
            ).getActionCards(),
            onCardAction: { _ in },
            onDismissCard: { _ in }
        )

        Divider()

        // Pro user cards
        ActionCardsStack(
            cards: ActionCardsManager(
                subscriptionTier: "pro",
                hasRSSFeeds: true,
                hasAutoProcessing: false,
                hasDigests: false,
                unreadYesterdayCount: 3,
                totalUnprocessedCount: 8
            ).getActionCards(),
            onCardAction: { _ in },
            onDismissCard: { _ in }
        )

        Divider()

        // Ultimate user cards
        ActionCardsStack(
            cards: ActionCardsManager(
                subscriptionTier: "ultimate",
                hasRSSFeeds: true,
                hasAutoProcessing: true,
                hasDigests: false,
                unreadYesterdayCount: 7,
                totalUnprocessedCount: 15
            ).getActionCards(),
            onCardAction: { _ in },
            onDismissCard: { _ in }
        )
    }
    .padding()
}
