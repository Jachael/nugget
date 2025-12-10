import SwiftUI

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [Friend] = []
    @State private var friendRequests: [FriendRequest] = []
    @State private var myFriendCode: String?
    @State private var isLoading = true
    @State private var showAddFriend = false
    @State private var friendCodeInput = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isSubmitting = false
    @State private var showSharedWithMe = false
    @State private var unreadSharedCount = 0

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 24) {
                // Shared With Me Section
                Button {
                    showSharedWithMe = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.title2)
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shared With Me")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Nuggets your friends have shared")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if unreadSharedCount > 0 {
                            Text("\(unreadSharedCount)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)

                // My Friend Code Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Friend Code")
                        .font(.title3.bold())
                        .padding(.horizontal)

                    VStack(spacing: 16) {
                        if let code = myFriendCode {
                            HStack {
                                Text(code)
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .kerning(2)

                                Spacer()

                                Button {
                                    UIPasteboard.general.string = code
                                    HapticFeedback.selection()
                                    withAnimation {
                                        successMessage = "Copied to clipboard!"
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation {
                                            if successMessage == "Copied to clipboard!" {
                                                successMessage = nil
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(HapticPlainButtonStyle())

                                ShareLink(item: "Add me on Nugget! My friend code is: \(code)") {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Text("Share this code with friends so they can add you")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 16))
                    .padding(.horizontal)
                }

                // Add Friend Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Add a Friend")
                        .font(.title3.bold())
                        .padding(.horizontal)

                    VStack(spacing: 16) {
                        HStack {
                            TextField("Enter friend code", text: $friendCodeInput)
                                .font(.system(size: 16, design: .monospaced))
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)

                            Button {
                                sendFriendRequest()
                            } label: {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Add")
                                        .fontWeight(.semibold)
                                }
                            }
                            .disabled(friendCodeInput.count < 8 || isSubmitting)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(friendCodeInput.count >= 8 ? Color.primary : Color.secondary.opacity(0.3))
                            .foregroundColor(friendCodeInput.count >= 8 ? Color(UIColor.systemBackground) : Color.secondary)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 16))
                    .padding(.horizontal)
                }

                // Error/Success Messages
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Spacer()
                        Button {
                            withAnimation {
                                errorMessage = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                if let success = successMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(success)
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Friend Requests Section
                if !friendRequests.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Friend Requests")
                                .font(.title3.bold())
                            Text("\(friendRequests.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(friendRequests) { request in
                                FriendRequestRow(
                                    request: request,
                                    onAccept: { acceptRequest(request) },
                                    onDecline: { declineRequest(request) }
                                )

                                if request.id != friendRequests.last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }

                // Friends List Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Friends")
                            .font(.title3.bold())
                        Text("\(friends.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Loading friends...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    } else if friends.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                                .symbolRenderingMode(.hierarchical)

                            Text("No friends yet")
                                .font(.headline)

                            Text("Share your friend code or add friends using their code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(friends) { friend in
                                FriendRow(friend: friend) {
                                    removeFriend(friend)
                                }

                                if friend.id != friends.last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.medium)
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .sheet(isPresented: $showSharedWithMe) {
            SharedWithMeView()
        }
        }
    }

    private func loadData() async {
        isLoading = true

        async let codeTask = FriendsService.shared.getFriendCode()
        async let friendsTask = FriendsService.shared.listFriends()
        async let requestsTask = FriendsService.shared.listFriendRequests()
        async let sharedTask = FriendsService.shared.getSharedWithMe()

        do {
            let (code, loadedFriends, loadedRequests, sharedResponse) = try await (codeTask, friendsTask, requestsTask, sharedTask)
            await MainActor.run {
                myFriendCode = code
                friends = loadedFriends
                friendRequests = loadedRequests
                unreadSharedCount = sharedResponse.unreadCount
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to load friends data"
            }
        }
    }

    private func sendFriendRequest() {
        guard friendCodeInput.count >= 8 else { return }
        isSubmitting = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                let message = try await FriendsService.shared.sendFriendRequest(friendCode: friendCodeInput)
                await MainActor.run {
                    successMessage = message
                    friendCodeInput = ""
                    isSubmitting = false
                    HapticFeedback.success()
                }
            } catch let error as APIError {
                await MainActor.run {
                    switch error {
                    case .serverError(let message):
                        errorMessage = message
                    default:
                        errorMessage = "Failed to send friend request"
                    }
                    isSubmitting = false
                    HapticFeedback.error()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                    HapticFeedback.error()
                }
            }
        }
    }

    private func acceptRequest(_ request: FriendRequest) {
        Task {
            do {
                try await FriendsService.shared.acceptFriendRequest(requestId: request.requestId)
                await MainActor.run {
                    withAnimation {
                        friendRequests.removeAll { $0.id == request.id }
                    }
                    successMessage = "Friend request accepted!"
                    HapticFeedback.success()
                }
                // Reload friends list
                let updatedFriends = try await FriendsService.shared.listFriends()
                await MainActor.run {
                    friends = updatedFriends
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to accept request"
                    HapticFeedback.error()
                }
            }
        }
    }

    private func declineRequest(_ request: FriendRequest) {
        Task {
            do {
                try await FriendsService.shared.declineFriendRequest(requestId: request.requestId)
                await MainActor.run {
                    withAnimation {
                        friendRequests.removeAll { $0.id == request.id }
                    }
                    HapticFeedback.selection()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to decline request"
                    HapticFeedback.error()
                }
            }
        }
    }

    private func removeFriend(_ friend: Friend) {
        Task {
            do {
                try await FriendsService.shared.removeFriend(friendId: friend.userId)
                await MainActor.run {
                    withAnimation {
                        friends.removeAll { $0.id == friend.id }
                    }
                    HapticFeedback.selection()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to remove friend"
                    HapticFeedback.error()
                }
            }
        }
    }
}

// MARK: - Friend Request Row

struct FriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromDisplayName)
                    .font(.body)
                    .fontWeight(.medium)
                Text("Wants to be friends")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    onDecline()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(18)
                }

                Button {
                    onAccept()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.green)
                        .cornerRadius(18)
                }
            }
        }
        .padding()
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friend: Friend
    let onRemove: () -> Void
    @State private var showRemoveConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                if let code = friend.friendCode {
                    Text(code)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                showRemoveConfirmation = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
            }
            .confirmationDialog("Remove Friend", isPresented: $showRemoveConfirmation, titleVisibility: .visible) {
                Button("Remove \(friend.displayName)", role: .destructive) {
                    onRemove()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to remove this friend?")
            }
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        FriendsView()
    }
}
