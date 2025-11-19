import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var preferences: UserPreferences?
    @State private var nuggets: [Nugget] = []
    @State private var isLoadingPreferences = true
    @State private var isLoadingNuggets = true
    @State private var showingEditPreferences = false
    @AppStorage("colorScheme") private var colorScheme: String = "system"

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
                    // Profile Header with full-width streak card
                    VStack(spacing: 20) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)

                        // Full-width user card
                        HStack(spacing: 16) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.orange)
                                .frame(width: 50)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(username)
                                    .font(.title3.bold())
                                    .foregroundColor(.primary)

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
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Stats Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        StatCard(
                            title: "Total Articles",
                            value: "\(totalNuggets)",
                            icon: "doc.text.fill"
                        )

                        StatCard(
                            title: "Processed",
                            value: "\(processedNuggets)",
                            icon: "checkmark.circle.fill"
                        )

                        StatCard(
                            title: "Categories",
                            value: "\(categoriesCount)",
                            icon: "tag.fill"
                        )

                        StatCard(
                            title: "Streak",
                            value: "\(authService.currentUser?.streak ?? 0)",
                            icon: "flame.fill"
                        )
                    }
                    .padding(.horizontal)

                    // Appearance Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Appearance")
                            .font(.title3.bold())
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            HStack {
                                Label("Theme", systemImage: "moon.circle.fill")
                                    .foregroundColor(.primary)
                                Spacer()
                                Picker("Theme", selection: $colorScheme) {
                                    Label("System", systemImage: "gear")
                                        .tag("system")
                                    Label("Light", systemImage: "sun.max")
                                        .tag("light")
                                    Label("Dark", systemImage: "moon")
                                        .tag("dark")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 180)
                            }
                            .padding()
                        }
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Preferences Section
                    if let prefs = preferences {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Preferences")
                                .font(.title3.bold())
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                NavigationLink {
                                    EditPreferencesView(preferences: prefs) { updated in
                                        preferences = updated
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Interests")
                                                .font(.body)
                                            Text("\(prefs.interests.count) selected")
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

                                Divider()
                                    .padding(.horizontal)

                                HStack {
                                    Text("Daily Nuggets")
                                    Spacer()
                                    HStack(spacing: 6) {
                                        Text("\(prefs.dailyNuggetLimit)")
                                            .fontWeight(.medium)
                                        if prefs.subscriptionTier == .premium {
                                            Image(systemName: "crown.fill")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                    }
                                    .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                            .glassEffect(in: .rect(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                    }

                    // Sign Out Button
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
                    .buttonStyle(GlassButtonStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                loadPreferences()
                loadNuggets()
            }
        }
    }

    private func loadPreferences() {
        isLoadingPreferences = true

        Task {
            do {
                let prefs = try await PreferencesService.shared.getPreferences()
                await MainActor.run {
                    preferences = prefs
                    isLoadingPreferences = false
                }
            } catch {
                await MainActor.run {
                    isLoadingPreferences = false
                }
                print("Error loading preferences: \(error)")
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

struct EditPreferencesView: View {
    @Environment(\.dismiss) var dismiss
    let preferences: UserPreferences
    let onSave: (UserPreferences) -> Void

    @State private var selectedInterests: Set<String>
    @State private var dailyNuggetLimit: Int
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let categories = UserPreferences.defaultCategories

    init(preferences: UserPreferences, onSave: @escaping (UserPreferences) -> Void) {
        self.preferences = preferences
        self.onSave = onSave
        _selectedInterests = State(initialValue: Set(preferences.interests))
        _dailyNuggetLimit = State(initialValue: preferences.dailyNuggetLimit)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Interests")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Choose topics you'd like to learn about")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryButton(
                                title: category.capitalized,
                                isSelected: selectedInterests.contains(category)
                            ) {
                                if selectedInterests.contains(category) {
                                    selectedInterests.remove(category)
                                } else {
                                    selectedInterests.insert(category)
                                }
                            }
                        }
                    }
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16))
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Daily Nuggets")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("How many nuggets would you like per day?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(spacing: 12) {
                        Picker("Daily Nuggets", selection: $dailyNuggetLimit) {
                            Text("1 nugget (Free)").tag(1)
                            Text("3 nuggets").tag(3)
                            Text("5 nuggets").tag(5)
                            Text("10 nuggets").tag(10)
                        }
                        .pickerStyle(.segmented)

                        if dailyNuggetLimit > 1 {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.secondary)
                                Text("Premium feature")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .glassEffect(in: .capsule)
                        }
                    }
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16))
                .padding(.horizontal)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 10))
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Edit Preferences")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    savePreferences()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(selectedInterests.isEmpty || isSaving)
            }
        }
    }

    private func savePreferences() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let updated = UserPreferences(
                    interests: Array(selectedInterests),
                    dailyNuggetLimit: dailyNuggetLimit,
                    subscriptionTier: dailyNuggetLimit > 1 ? .premium : .free,
                    customCategories: preferences.customCategories,
                    categoryWeights: preferences.categoryWeights,
                    onboardingCompleted: true
                )

                let result = try await PreferencesService.shared.updatePreferences(updated)

                await MainActor.run {
                    isSaving = false
                    onSave(result)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save preferences. Please try again."
                    print("Error saving preferences: \(error)")
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService())
}
