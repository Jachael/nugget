import SwiftUI

struct CatchUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var customQuery = ""
    @State private var isProcessing = false
    @State private var processingComplete = false
    @State private var errorMessage: String?

    let unprocessedCount: Int
    let availableCategories: [String] // Categories with unprocessed content
    let onSessionCreated: (Session) -> Void

    // Time-based greeting
    var timeBasedPrompt: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "What would you like to catch up on?"
        } else if hour < 17 {
            return "What would you like to catch up on?"
        } else {
            return "What would you like to catch up on?"
        }
    }

    // Dynamic quick suggestions based on available content
    var quickSuggestions: [(title: String, query: String, icon: String)] {
        var suggestions: [(String, String, String)] = []

        // Add category-based suggestions for categories with content
        let categoryIcons: [String: String] = [
            "tech": "desktopcomputer",
            "technology": "desktopcomputer",
            "sport": "sportscourt",
            "sports": "sportscourt",
            "business": "briefcase",
            "finance": "chart.line.uptrend.xyaxis",
            "health": "heart",
            "science": "atom",
            "news": "newspaper",
            "entertainment": "play.tv",
            "career": "person.crop.square"
        ]

        // Add available category suggestions
        for category in availableCategories.prefix(3) {
            let icon = categoryIcons[category.lowercased()] ?? "tag"
            suggestions.append(("\(category.capitalized) today", "\(category) today", icon))
        }

        // Always add time-based suggestions if there's content
        if unprocessedCount > 0 {
            if !suggestions.contains(where: { $0.1.contains("yesterday") }) {
                suggestions.append(("Yesterday's news", "catch me up on yesterday", "clock.arrow.circlepath"))
            }
            if !suggestions.contains(where: { $0.1.contains("today") }) && suggestions.count < 4 {
                suggestions.append(("Today's digest", "everything from today", "sun.max"))
            }
            if suggestions.count < 4 {
                suggestions.append(("This week", "catch me up on this week", "calendar"))
            }
        }

        return Array(suggestions.prefix(4))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 6) {
                        Text(timeBasedPrompt)
                            .font(.title3.bold())

                        if unprocessedCount > 0 {
                            Text("\(unprocessedCount) items available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 24)

                    // Custom query input
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)

                            TextField("Yesterday's tech news...", text: $customQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .submitLabel(.go)
                                .onSubmit {
                                    if !customQuery.isEmpty {
                                        processQuery(customQuery)
                                    }
                                }

                            if !customQuery.isEmpty {
                                Button {
                                    customQuery = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))

                        // Show action button when there's text
                        if !customQuery.isEmpty && !isProcessing {
                            Button {
                                processQuery(customQuery)
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14))
                                    Text("Catch me up")
                                        .font(.system(size: 15, weight: .medium))
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.2), value: customQuery.isEmpty)

                    // Quick suggestions
                    if unprocessedCount > 0 && !quickSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick options")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(quickSuggestions, id: \.query) { suggestion in
                                    QuickSuggestionCard(
                                        title: suggestion.title,
                                        icon: suggestion.icon,
                                        isProcessing: isProcessing,
                                        isComplete: processingComplete
                                    ) {
                                        processQuery(suggestion.query)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Processing state
                    if isProcessing {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Creating your catch-up...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .transition(.opacity)
                    }

                    // Empty state
                    if unprocessedCount == 0 {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                                .symbolRenderingMode(.hierarchical)

                            Text("You're all caught up!")
                                .font(.headline)

                            Text("Add more content to your feed or check back later")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .padding(.horizontal)
                    }

                    // Error message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.secondary)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    private func processQuery(_ query: String) {
        guard !isProcessing else { return }

        isProcessing = true
        errorMessage = nil
        HapticFeedback.selection()

        Task {
            do {
                let session = try await NuggetService.shared.createSmartSession(query: query)

                await MainActor.run {
                    // Check if we got any nuggets back
                    if session.nuggets.isEmpty {
                        isProcessing = false
                        errorMessage = "You're all caught up! No unread nuggets match that query."
                        return
                    }

                    withAnimation(.easeInOut(duration: 0.3)) {
                        processingComplete = true
                        isProcessing = false
                    }

                    // Short delay to show success, then dismiss and navigate
                    Task {
                        try? await Task.sleep(for: .seconds(0.4))
                        dismiss()
                        onSessionCreated(session)
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshNuggets"), object: nil)
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false

                    // Parse error message
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .serverError(let message):
                            if message.contains("No matching") || message.contains("caught up") {
                                errorMessage = "You're all caught up! No unread nuggets match that query."
                            } else {
                                errorMessage = message
                            }
                        default:
                            errorMessage = "Something went wrong. Please try again."
                        }
                    } else {
                        errorMessage = "No matching content found"
                    }
                }
            }
        }
    }
}

// MARK: - Quick Suggestion Card

struct QuickSuggestionCard: View {
    let title: String
    let icon: String
    let isProcessing: Bool
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isProcessing || isComplete)
        .opacity(isProcessing || isComplete ? 0.6 : 1)
    }
}

#Preview {
    CatchUpView(
        unprocessedCount: 15,
        availableCategories: ["tech", "sport", "business"]
    ) { _ in }
    .environmentObject(AuthService())
}
