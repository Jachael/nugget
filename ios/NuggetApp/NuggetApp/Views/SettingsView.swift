import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var nuggets: [Nugget] = []
    @State private var isLoadingNuggets = true
    @State private var showingDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    @State private var isProfileExpanded = false
    @AppStorage("colorScheme") private var colorScheme: String = "system"

    private var subscriptionTier: String {
        authService.currentUser?.subscriptionTier ?? "free"
    }

    private var isPremium: Bool {
        subscriptionTier == "pro" || subscriptionTier == "ultimate"
    }

    private var isUltimate: Bool {
        subscriptionTier == "ultimate"
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

    private var username: String {
        if let user = authService.currentUser {
            if let firstName = user.firstName, !firstName.isEmpty {
                return firstName
            }
        }
        return "User"
    }

    var totalNuggets: Int {
        nuggets.count
    }

    var processedNuggets: Int {
        nuggets.filter { $0.summary != nil }.count
    }

    var categoriesCount: Int {
        Set(nuggets.compactMap { $0.category }).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header with expandable stats
                    VStack(spacing: 0) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isProfileExpanded.toggle()
                            }
                        } label: {
                            VStack(spacing: 0) {
                                HStack(spacing: 16) {
                                    Image(systemName: "brain.head.profile.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.primary)
                                        .frame(width: 50)

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text(username)
                                                .font(.title3.bold())
                                                .foregroundColor(.primary)

                                            // Subscription badge
                                            if isPremium {
                                                Text(subscriptionTier.uppercased())
                                                    .font(.caption2.bold())
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(Color.secondary)
                                                    .cornerRadius(6)
                                            }
                                        }

                                        HStack(spacing: 12) {
                                            HStack(spacing: 4) {
                                                Text("\(authService.currentUser?.streak ?? 0)")
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                Text("day streak")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }

                                            Text("·")
                                                .foregroundColor(.secondary)

                                            Text(getUserLevel(streak: authService.currentUser?.streak ?? 0))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: isProfileExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .rotationEffect(.degrees(isProfileExpanded ? 0 : 0))
                                }
                                .padding()

                                // Expandable Stats Section
                                if isProfileExpanded {
                                    VStack(spacing: 0) {
                                        Divider()
                                            .padding(.horizontal)

                                        LazyVGrid(columns: [
                                            GridItem(.flexible(), spacing: 12),
                                            GridItem(.flexible(), spacing: 12)
                                        ], spacing: 12) {
                                            CompactStatCard(
                                                title: "Total Articles",
                                                value: "\(totalNuggets)",
                                                icon: "doc.text.fill"
                                            )

                                            CompactStatCard(
                                                title: "Processed",
                                                value: "\(processedNuggets)",
                                                icon: "checkmark.circle.fill"
                                            )

                                            CompactStatCard(
                                                title: "Categories",
                                                value: "\(categoriesCount)",
                                                icon: "tag.fill"
                                            )

                                            CompactStatCard(
                                                title: "Streak",
                                                value: "\(authService.currentUser?.streak ?? 0)",
                                                icon: "square.stack.3d.up.fill"
                                            )
                                        }
                                        .padding()
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .glassEffect(in: .rect(cornerRadius: 16))
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // Subscription Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Subscription")
                            .font(.title3.bold())
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            NavigationLink {
                                SubscriptionView()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(isPremium ? "Manage Subscription" : "Upgrade to Premium")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(isPremium ? "\(subscriptionTier.capitalized) Plan" : "Unlock all features")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if !isPremium {
                                        Text("✦")
                                            .font(.title3)
                                            .foregroundColor(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Premium Features Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Premium Features")
                                .font(.title3.bold())
                            if !isPremium {
                                Text("✦")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        VStack(spacing: 0) {
                            // Smart Processing
                            NavigationLink {
                                AutoProcessingSettingsView()
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles.rectangle.stack")
                                        .foregroundColor(.secondary)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Smart Processing")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("Schedule automatic content processing")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if !isPremium {
                                        LockedBadge()
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }

                            Divider().padding(.horizontal)

                            // RSS Feeds
                            NavigationLink {
                                RSSFeedsView()
                            } label: {
                                HStack {
                                    Image(systemName: "dot.radiowaves.up.forward")
                                        .foregroundColor(.secondary)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("RSS Feeds")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("Subscribe to quality news sources")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if !isPremium {
                                        LockedBadge()
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }

                            Divider().padding(.horizontal)

                            // Custom Digests (Ultimate)
                            NavigationLink {
                                CustomDigestsView()
                            } label: {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.secondary)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Custom Digests")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("Combine feeds into personalized summaries")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if !isUltimate {
                                        UltimateBadge()
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }

                            Divider().padding(.horizontal)

                            // Offline Mode (Ultimate)
                            NavigationLink {
                                OfflineNuggetsView()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(.secondary)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Offline Mode")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("Read nuggets without internet")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if !isUltimate {
                                        UltimateBadge()
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }

                            Divider().padding(.horizontal)

                            // Reader Mode
                            NavigationLink {
                                ReaderModeSettingsView()
                            } label: {
                                HStack {
                                    Image(systemName: "doc.plaintext")
                                        .foregroundColor(.secondary)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Reader Mode")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("Strip ads and distractions from articles")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if !isPremium {
                                        LockedBadge()
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // General Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("General")
                            .font(.title3.bold())
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            // Notifications
                            NavigationLink {
                                NotificationConfigView()
                            } label: {
                                HStack {
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundColor(.secondary)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Notifications")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("Get notified when content is ready")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Coming Soon Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Coming Soon")
                                .font(.title3.bold())
                            Image(systemName: "sparkle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 0) {
                            // Widgets & Quick Actions (Pro)
                            HStack {
                                Image(systemName: "square.grid.2x2.fill")
                                    .foregroundColor(.secondary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Widgets & Quick Actions")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text("Home screen widgets and Siri shortcuts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isPremium {
                                    ComingSoonBadge()
                                } else {
                                    LockedBadge()
                                }
                            }
                            .padding()

                            Divider().padding(.horizontal)

                            // Audio Mode (Pro)
                            HStack {
                                Image(systemName: "headphones")
                                    .foregroundColor(.secondary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Audio Mode")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text("Listen to your nuggets on the go")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isPremium {
                                    ComingSoonBadge()
                                } else {
                                    LockedBadge()
                                }
                            }
                            .padding()

                            Divider().padding(.horizontal)

                            // X Integration (Ultimate)
                            HStack {
                                Image(systemName: "at")
                                    .foregroundColor(.secondary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("X Integration")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text("Save posts and threads as nuggets")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isUltimate {
                                    ComingSoonBadge()
                                } else {
                                    UltimateBadge()
                                }
                            }
                            .padding()

                            Divider().padding(.horizontal)

                            // Challenges & Leaderboards (Free)
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(.secondary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Challenges & Leaderboards")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text("Compete with friends and earn badges")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                ComingSoonBadge()
                            }
                            .padding()

                            Divider().padding(.horizontal)

                            // Nugget Desktop (Ultimate)
                            HStack {
                                Image(systemName: "desktopcomputer")
                                    .foregroundColor(.secondary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Nugget Desktop")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text("Access your nuggets on Mac and Windows")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isUltimate {
                                    ComingSoonBadge()
                                } else {
                                    UltimateBadge()
                                }
                            }
                            .padding()
                        }
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Social Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Social")
                            .font(.title3.bold())
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            NavigationLink {
                                FriendsView()
                            } label: {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.secondary)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Friends")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("Add friends and share nuggets")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Help & Support Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Help & Support")
                            .font(.title3.bold())
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            NavigationLink {
                                TutorialView()
                            } label: {
                                HStack {
                                    Image(systemName: "book.closed.fill")
                                        .foregroundColor(.secondary)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("How to Use Nugget")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("Learn the basics and tips")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }

                            Divider().padding(.horizontal)

                            Button {
                                openFeedbackPage()
                            } label: {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.secondary)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Suggest a Feature")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("Vote on ideas and submit feedback")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Appearance Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Appearance")
                            .font(.title3.bold())
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "moon.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .frame(width: 28)

                                Text("Theme")
                                    .font(.body)
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)

                            HStack(spacing: 12) {
                                ThemeButton(
                                    title: "System",
                                    icon: "gear",
                                    isSelected: colorScheme == "system"
                                ) {
                                    colorScheme = "system"
                                }

                                ThemeButton(
                                    title: "Light",
                                    icon: "sun.max",
                                    isSelected: colorScheme == "light"
                                ) {
                                    colorScheme = "light"
                                }

                                ThemeButton(
                                    title: "Dark",
                                    icon: "moon",
                                    isSelected: colorScheme == "dark"
                                ) {
                                    colorScheme = "dark"
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                        }
                        .padding(.vertical, 12)
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Account Actions
                    VStack(spacing: 12) {
                        Button(role: .destructive) {
                            authService.signOut()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Sign Out")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(LiquidGlassButtonStyle())

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                if isDeletingAccount {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Delete Account")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                        .foregroundColor(.red)
                        .disabled(isDeletingAccount)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                loadNuggets()
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.")
            }
            .alert("Error", isPresented: .constant(deleteError != nil)) {
                Button("OK") {
                    deleteError = nil
                }
            } message: {
                if let error = deleteError {
                    Text(error)
                }
            }
        }
    }

    private func loadNuggets() {
        isLoadingNuggets = true

        Task {
            do {
                let loadedNuggets = try await NuggetService.shared.listNuggets()
                await MainActor.run {
                    nuggets = loadedNuggets
                    isLoadingNuggets = false
                }
            } catch {
                await MainActor.run {
                    isLoadingNuggets = false
                }
            }
        }
    }

    private func deleteAccount() {
        isDeletingAccount = true
        deleteError = nil

        Task {
            do {
                try await authService.deleteAccount()
                await MainActor.run {
                    authService.signOut()
                }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    deleteError = "Failed to delete account: \(error.localizedDescription)"
                }
            }
        }
    }

    private func openFeedbackPage() {
        // Get auth token and open feedback page
        if let token = KeychainManager.shared.getToken(),
           let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://nuggetdotcom.com/feedback.html?token=\(encodedToken)") {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "https://nuggetdotcom.com/feedback.html") {
            // Fall back to opening without token
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Locked Badge
struct LockedBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.8))
            .cornerRadius(4)
    }
}

// MARK: - Ultimate Badge
struct UltimateBadge: View {
    var body: some View {
        Text("ULTIMATE")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.8))
            .cornerRadius(4)
    }
}

// MARK: - Coming Soon Badge
struct ComingSoonBadge: View {
    var body: some View {
        Text("SOON")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.7))
            .cornerRadius(4)
    }
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @State private var nuggetsReady = true
    @State private var streakReminders = true
    @State private var newContent = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Notification Preferences")
                        .font(.title3.bold())
                        .padding(.horizontal)

                    VStack(spacing: 0) {
                        Toggle(isOn: $nuggetsReady) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nuggets Ready")
                                    .font(.body)
                                Text("When your content is processed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()

                        Divider().padding(.horizontal)

                        Toggle(isOn: $streakReminders) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Streak Reminders")
                                    .font(.body)
                                Text("Daily reminder to maintain your streak")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()

                        Divider().padding(.horizontal)

                        Toggle(isOn: $newContent) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("New Content")
                                    .font(.body)
                                Text("When new RSS feed content arrives")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }
                    .glassEffect(in: .rect(cornerRadius: 16))
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .navigationTitle("Notifications")
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text(value)
                    .font(.title.bold())
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

// MARK: - Compact Stat Card
struct CompactStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.secondary)

            VStack(spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Theme Button
struct ThemeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .primary : .secondary)

                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                Group {
                    if isSelected {
                        Color.primary.opacity(0.1)
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService())
}
