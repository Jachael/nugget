import SwiftUI

struct ShareToFriendsSheet: View {
    let nuggetId: String
    let nuggetTitle: String?
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [Friend] = []
    @State private var selectedFriendIds: Set<String> = []
    @State private var isLoading = true
    @State private var isSharing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if friends.isEmpty {
                    emptyView
                } else {
                    friendsList
                }
            }
            .navigationTitle("Share to Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        shareToSelectedFriends()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedFriendIds.isEmpty || isSharing)
                }
            }
        }
        .task {
            await loadFriends()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading friends...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No friends yet")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Add friends to share nuggets with them")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink {
                FriendsView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Add Friends")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color(UIColor.systemBackground))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.primary)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var friendsList: some View {
        VStack(spacing: 0) {
            // Nugget preview
            if let title = nuggetTitle {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sharing:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
            }

            // Friends selection
            List(friends, selection: $selectedFriendIds) { friend in
                FriendSelectionRow(
                    friend: friend,
                    isSelected: selectedFriendIds.contains(friend.userId)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelection(friend.userId)
                }
            }
            .listStyle(.plain)

            // Selection count
            if !selectedFriendIds.isEmpty {
                HStack {
                    Text("\(selectedFriendIds.count) friend\(selectedFriendIds.count == 1 ? "" : "s") selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    if isSharing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
        }
    }

    private func toggleSelection(_ friendId: String) {
        HapticFeedback.selection()
        if selectedFriendIds.contains(friendId) {
            selectedFriendIds.remove(friendId)
        } else {
            selectedFriendIds.insert(friendId)
        }
    }

    private func loadFriends() async {
        isLoading = true
        do {
            friends = try await FriendsService.shared.listFriends()
            isLoading = false
        } catch {
            errorMessage = "Failed to load friends"
            isLoading = false
        }
    }

    private func shareToSelectedFriends() {
        guard !selectedFriendIds.isEmpty else { return }

        isSharing = true
        HapticFeedback.light()

        Task {
            do {
                let response = try await FriendsService.shared.shareNuggetToFriends(
                    nuggetId: nuggetId,
                    friendIds: Array(selectedFriendIds)
                )

                await MainActor.run {
                    isSharing = false
                    if response.success {
                        HapticFeedback.success()
                        dismiss()
                    } else {
                        errorMessage = "Failed to share"
                        HapticFeedback.error()
                    }
                }
            } catch {
                await MainActor.run {
                    isSharing = false
                    errorMessage = "Failed to share: \(error.localizedDescription)"
                    HapticFeedback.error()
                }
            }
        }
    }
}

// MARK: - Friend Selection Row

struct FriendSelectionRow: View {
    let friend: Friend
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(friend.displayName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)

                if let code = friend.friendCode {
                    Text(code)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isSelected ? .blue : .secondary.opacity(0.3))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ShareToFriendsSheet(nuggetId: "test-123", nuggetTitle: "How AI is Transforming Healthcare")
}
