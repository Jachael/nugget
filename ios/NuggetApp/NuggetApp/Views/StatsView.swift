import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var nuggets: [Nugget] = []
    @State private var isLoading = true
    @State private var friends: [Friend] = []
    @State private var friendCode: String = ""
    @State private var showAddFriend = false
    @State private var showFriendsView = false

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
            // Extract username from userId (e.g., "usr_mock_test_user_123" -> "User")
            let components = user.userId.components(separatedBy: "_")
            if components.count > 3 {
                return components[3].capitalized
            }
        }
        return "User"
    }

    // Computed stats
    var currentStreak: Int {
        authService.currentUser?.streak ?? 0
    }

    var totalNuggets: Int {
        nuggets.count
    }

    var processedNuggets: Int {
        nuggets.filter { $0.summary != nil }.count
    }

    var unprocessedNuggets: Int {
        nuggets.filter { $0.summary == nil }.count
    }

    var categoryCounts: [(String, Int)] {
        let grouped = Dictionary(grouping: nuggets) { $0.category ?? "General" }
        return grouped.map { ($0.key.capitalized, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    var weeklyActivity: [(Date, Int)] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]

        // Get last 7 days
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) {
                let startOfDay = calendar.startOfDay(for: date)
                let dayNuggets = nuggets.filter {
                    calendar.isDate($0.createdAt, inSameDayAs: startOfDay)
                }
                counts[startOfDay] = dayNuggets.count
            }
        }

        return counts.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with streak
                    streakHeader

                    // Friends section
                    friendsSection

                    // Main stats grid
                    statsGrid

                    // Weekly activity chart
                    weeklyActivityCard

                    // Category breakdown
                    categoryBreakdownCard

                    // Fun facts
                    funFactsCard
                }
                .padding()
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGray6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Your Stats")
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .task {
            await loadNuggets()
            await loadFriends()
        }
        .sheet(isPresented: $showFriendsView) {
            FriendsView()
        }
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Friends")
                    .font(.headline)

                Spacer()

                Button {
                    showFriendsView = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Manage")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.secondary)
                }
            }

            if friends.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No friends yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        showFriendsView = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                            Text("Add Friends")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(in: .capsule)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Friends list
                VStack(spacing: 12) {
                    ForEach(friends.prefix(3)) { friend in
                        HStack(spacing: 12) {
                            // Avatar circle
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
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)

                                if let code = friend.friendCode {
                                    Text(code)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                    }

                    if friends.count > 3 {
                        Button {
                            showFriendsView = true
                        } label: {
                            Text("See all \(friends.count) friends")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // My friend code
            if !friendCode.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Friend Code")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(friendCode)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Button {
                        UIPasteboard.general.string = friendCode
                        HapticFeedback.light()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .glassEffect(in: .circle)
                    }

                    ShareLink(item: "Add me on Nugget! My friend code is: \(friendCode)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .glassEffect(in: .circle)
                    }
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 12))
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private func loadFriends() async {
        do {
            friends = try await FriendsService.shared.listFriends()
            friendCode = try await FriendsService.shared.getFriendCode()
        } catch {
            print("Failed to load friends: \(error)")
        }
    }

    private var streakHeader: some View {
        VStack(spacing: 16) {
            // Full-width streak card
            HStack(spacing: 16) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.secondary, .yellow)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 6) {
                    Text(username)
                        .font(.title3.bold())
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("\(currentStreak)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("day streak")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text("·")
                            .foregroundColor(.secondary)

                        Text(getUserLevel(streak: currentStreak))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        if let tier = authService.currentUser?.subscriptionTier {
                            Text("·")
                                .foregroundColor(.secondary)

                            Text(tier.capitalized)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(tier == "free" ? .secondary : .yellow)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .glassEffect(in: .rect(cornerRadius: 16))

            Text(getStreakMessage())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
                StatsCard(
                    title: "Total Nuggets",
                    value: "\(totalNuggets)",
                    icon: "square.stack.3d.up.fill",
                    color: .secondary
                )

                StatsCard(
                    title: "Processed",
                    value: "\(processedNuggets)",
                    icon: "checkmark.seal.fill",
                    color: .secondary
                )

                StatsCard(
                    title: "In Queue",
                    value: "\(unprocessedNuggets)",
                    icon: "clock.fill",
                    color: .secondary
                )

                StatsCard(
                    title: "Categories",
                    value: "\(Set(nuggets.compactMap { $0.category }).count)",
                    icon: "tag.fill",
                    color: .secondary
                )
        }
    }

    private var weeklyActivityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Activity")
                .font(.headline)

            if !weeklyActivity.isEmpty {
                Chart(weeklyActivity, id: \.0) { item in
                    BarMark(
                        x: .value("Day", item.0, unit: .day),
                        y: .value("Nuggets", item.1)
                    )
                    .foregroundStyle(Color.secondary)
                    .cornerRadius(4)
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            } else {
                Text("No activity data yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Categories")
                .font(.headline)

            if !categoryCounts.isEmpty {
                ForEach(categoryCounts.prefix(5), id: \.0) { category, count in
                    HStack {
                        Text(category)
                            .font(.subheadline)

                        Spacer()

                        Text("\(count)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.secondary)

                        // Progress bar
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.secondary)
                                        .frame(width: geometry.size.width * CGFloat(count) / CGFloat(totalNuggets))
                                    ,
                                    alignment: .leading
                                )
                        }
                        .frame(width: 100, height: 4)
                    }
                }
            } else {
                Text("No categories yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private var funFactsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fun Facts")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if totalNuggets > 0 {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        Text("You've been learning for \(daysSinceFirstNugget()) days")
                            .font(.subheadline)
                    }
                }

                if processedNuggets > 0 {
                    HStack {
                        Image(systemName: "percent")
                            .foregroundColor(.secondary)
                        Text("\(Int(Double(processedNuggets) / Double(totalNuggets) * 100))% of your content is processed")
                            .font(.subheadline)
                    }
                }

                if let favoriteDay = getFavoriteDay() {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.secondary)
                        Text("You're most active on \(favoriteDay)")
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private func loadNuggets() async {
        do {
            nuggets = try await NuggetService.shared.listNuggets()
            isLoading = false
        } catch {
            print("Failed to load nuggets for stats: \(error)")
            isLoading = false
        }
    }

    private func getStreakMessage() -> String {
        switch currentStreak {
        case 0: return "Start your streak today!"
        case 1: return "Great start! Keep it going!"
        case 2...6: return "You're building momentum!"
        case 7...13: return "One week strong! 🎉"
        case 14...29: return "Two weeks! You're on fire! 🔥"
        case 30...59: return "A whole month! Incredible! 🌟"
        case 60...99: return "Two months! You're unstoppable! 💪"
        default: return "Legendary streak! Keep going! 🏆"
        }
    }

    private func daysSinceFirstNugget() -> Int {
        guard let oldestNugget = nuggets.min(by: { $0.createdAt < $1.createdAt }) else {
            return 0
        }
        return Calendar.current.dateComponents([.day], from: oldestNugget.createdAt, to: Date()).day ?? 0
    }

    private func getFavoriteDay() -> String? {
        let calendar = Calendar.current
        var dayCounts: [Int: Int] = [:] // weekday -> count

        for nugget in nuggets {
            let weekday = calendar.component(.weekday, from: nugget.createdAt)
            dayCounts[weekday, default: 0] += 1
        }

        guard let favoriteDay = dayCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }

        let formatter = DateFormatter()
        return formatter.weekdaySymbols[favoriteDay - 1]
    }
}

struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary.opacity(0.7))
                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 14))
    }
}

#Preview {
    StatsView()
        .environmentObject(AuthService())
}