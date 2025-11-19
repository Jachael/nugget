import SwiftUI

struct OnboardingView: View {
    @State private var selectedInterests: Set<String> = []
    @State private var dailyNuggetLimit = 1
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Binding var isOnboardingComplete: Bool

    private let categories = UserPreferences.defaultCategories

    var body: some View {
        NavigationView {
            ZStack {
                Color.clear
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)

                            Text("Welcome to Nugget")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Text("Let's personalize your learning experience")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)

                        // Interests Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Select Your Interests")
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
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // Daily Nugget Limit
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
                                            .foregroundColor(.yellow)
                                        Text("Premium feature")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.yellow.opacity(0.1), Color.yellow.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(.ultraThinMaterial, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal)
                        }

                        // Continue Button
                        Button {
                            savePreferences()
                        } label: {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title3)
                                    Text("Get Started")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: selectedInterests.isEmpty
                                        ? [Color.gray, Color.gray.opacity(0.8)]
                                        : [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .foregroundColor(.white)
                            .shadow(
                                color: selectedInterests.isEmpty ? Color.clear : Color.blue.opacity(0.3),
                                radius: 10,
                                x: 0,
                                y: 5
                            )
                        }
                        .disabled(selectedInterests.isEmpty || isLoading)
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }

    private func savePreferences() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let preferences = UserPreferences(
                    interests: Array(selectedInterests),
                    dailyNuggetLimit: dailyNuggetLimit,
                    subscriptionTier: dailyNuggetLimit > 1 ? .premium : .free,
                    customCategories: nil,
                    categoryWeights: nil,
                    onboardingCompleted: true
                )

                _ = try await PreferencesService.shared.updatePreferences(preferences)

                await MainActor.run {
                    isLoading = false
                    isOnboardingComplete = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save preferences. Please try again."
                    print("Error saving preferences: \(error)")
                }
            }
        }
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    isSelected
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ))
                        : AnyShapeStyle(.ultraThinMaterial)
                )
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected ? Color.clear : Color.primary.opacity(0.1),
                            lineWidth: 0.5
                        )
                )
                .shadow(
                    color: isSelected ? Color.blue.opacity(0.3) : Color.clear,
                    radius: 6,
                    x: 0,
                    y: 3
                )
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isOnboardingComplete: .constant(false))
    }
}
