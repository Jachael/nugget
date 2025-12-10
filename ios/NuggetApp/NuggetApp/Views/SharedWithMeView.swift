import SwiftUI

struct SharedWithMeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sharedNuggets: [SharedNugget] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if sharedNuggets.isEmpty {
                    emptyView
                } else {
                    nuggetsList
                }
            }
            .navigationTitle("Shared With Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .task {
            await loadSharedNuggets()
        }
        .refreshable {
            await loadSharedNuggets()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading shared nuggets...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No shared nuggets yet")
                .font(.headline)
                .foregroundColor(.primary)

            Text("When friends share nuggets with you,\nthey'll appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var nuggetsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sharedNuggets) { nugget in
                    SharedNuggetCard(
                        nugget: nugget,
                        onTap: { markAsRead(nugget) }
                    )
                }
            }
            .padding()
        }
    }

    private func loadSharedNuggets() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await FriendsService.shared.getSharedWithMe()
            await MainActor.run {
                sharedNuggets = response.sharedNuggets
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load shared nuggets"
                isLoading = false
            }
        }
    }

    private func markAsRead(_ nugget: SharedNugget) {
        guard !nugget.isRead else { return }

        Task {
            do {
                try await FriendsService.shared.markSharedAsRead(shareId: nugget.shareId)
                // Update local state
                await MainActor.run {
                    if let index = sharedNuggets.firstIndex(where: { $0.shareId == nugget.shareId }) {
                        // Create a new SharedNugget with isRead = true
                        let updated = SharedNugget(
                            shareId: nugget.shareId,
                            nuggetId: nugget.nuggetId,
                            senderUserId: nugget.senderUserId,
                            senderDisplayName: nugget.senderDisplayName,
                            sharedAt: nugget.sharedAt,
                            isRead: true,
                            title: nugget.title,
                            summary: nugget.summary,
                            sourceUrl: nugget.sourceUrl,
                            category: nugget.category
                        )
                        sharedNuggets[index] = updated
                    }
                }
            } catch {
                print("Failed to mark as read: \(error)")
            }
        }
    }
}

// MARK: - Shared Nugget Card

struct SharedNuggetCard: View {
    let nugget: SharedNugget
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with sender info
                HStack(spacing: 8) {
                    // Avatar
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(nugget.senderDisplayName.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(nugget.senderDisplayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)

                        Text(formatDate(nugget.sharedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Unread indicator
                    if !nugget.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }

                // Nugget content
                VStack(alignment: .leading, spacing: 8) {
                    if let title = nugget.title {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }

                    if let summary = nugget.summary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }

                    // Category badge
                    if let category = nugget.category {
                        Text(category.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(nugget.isRead ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return formatRelativeDate(date)
        }

        return formatRelativeDate(date)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 {
            return "Just now"
        } else if diff < 3600 {
            let mins = Int(diff / 60)
            return "\(mins)m ago"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours)h ago"
        } else if diff < 604800 {
            let days = Int(diff / 86400)
            return "\(days)d ago"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            return dateFormatter.string(from: date)
        }
    }
}

#Preview {
    SharedWithMeView()
}
