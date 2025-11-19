import SwiftUI

struct SmartProcessView: View {
    @Environment(\.dismiss) var dismiss
    @State private var customQuery = ""
    @State private var selectedPreset: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var session: Session?

    let unprocessedCount: Int
    let onSessionCreated: (Session) -> Void

    // Preset queries
    let presetQueries = [
        ("📱", "Tech This Week", "tech from this week"),
        ("💼", "Career Insights", "career advice"),
        ("⚡", "Quick Reads", "quick 5 minute reads"),
        ("📈", "Finance Updates", "finance and markets"),
        ("🧠", "Learn Something New", "interesting facts"),
        ("📅", "Today's Best", "best from today")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Smart Process")
                            .font(.title.bold())

                        Text("You have \(unprocessedCount) articles waiting")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Tell me what you want to learn")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Custom query input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What are you interested in?")
                            .font(.headline)

                        HStack {
                            TextField("e.g., tech news from this week", text: $customQuery)
                                .textFieldStyle(.plain)
                                .padding()
                                .glassEffect(in: .rect(cornerRadius: 12))

                            Button {
                                processQuery(customQuery)
                            } label: {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                            .disabled(customQuery.isEmpty || isProcessing)
                        }
                    }
                    .padding(.horizontal)

                    // Or divider
                    HStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)

                        Text("or choose a preset")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)

                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal)

                    // Preset queries grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(presetQueries, id: \.1) { emoji, title, query in
                            PresetQueryCard(
                                emoji: emoji,
                                title: title,
                                isSelected: selectedPreset == query,
                                isProcessing: isProcessing && selectedPreset == query
                            ) {
                                selectedPreset = query
                                processQuery(query)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Error message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .glassEffect(.regular.tint(.orange), in: .rect(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $session) { session in
            SessionView(session: session)
        }
    }

    private func processQuery(_ query: String) {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let newSession = try await NuggetService.shared.createSmartSession(query: query)
                await MainActor.run {
                    isProcessing = false
                    session = newSession
                    onSessionCreated(newSession)

                    // Dismiss after a short delay to show the session
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription

                    // Clear selection after error
                    selectedPreset = nil
                }
            }
        }
    }
}

struct PresetQueryCard: View {
    let emoji: String
    let title: String
    let isSelected: Bool
    let isProcessing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                if isProcessing {
                    ProgressView()
                        .frame(height: 40)
                } else {
                    Text(emoji)
                        .font(.system(size: 40))
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding()
            .glassEffect(
                isSelected ? .regular : .regular,
                in: .rect(cornerRadius: 16)
            )
        }
        .disabled(isProcessing)
    }
}

#Preview {
    SmartProcessView(unprocessedCount: 47) { _ in }
}