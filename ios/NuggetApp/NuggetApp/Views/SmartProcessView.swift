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

    // Preset queries with gradient colors
    let presetQueries = [
        ("Tech This Week", "tech from this week", [Color.blue, Color.purple]),
        ("Career Insights", "career advice", [Color.orange, Color.red]),
        ("Quick Reads", "quick 5 minute reads", [Color.green, Color.teal]),
        ("Finance Updates", "finance and markets", [Color.purple, Color.pink]),
        ("Learn Something", "interesting facts", [Color.indigo, Color.blue]),
        ("Today's Best", "best from today", [Color.yellow, Color.orange])
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("What do you want to learn?")
                            .font(.title2.bold())

                        Text("\(unprocessedCount) items ready to process")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Custom query input
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)

                            TextField("Search your saved content...", text: $customQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))

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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .glassEffect(in: .capsule)
                        .padding(.horizontal)

                        if !customQuery.isEmpty {
                            Button {
                                processQuery(customQuery)
                            } label: {
                                HStack {
                                    Text("Search for \"\(customQuery)\"")
                                        .font(.system(size: 15))
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .glassEffect(in: .rect(cornerRadius: 12))
                                .padding(.horizontal)
                            }
                            .disabled(isProcessing)
                        }
                    }

                    // Suggestions header
                    Text("Popular searches")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Preset queries grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(presetQueries, id: \.0) { title, query, colors in
                            PresetQueryCard(
                                title: title,
                                gradientColors: colors,
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
    let title: String
    let gradientColors: [Color]
    let isSelected: Bool
    let isProcessing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(isSelected ? 0.8 : 0.6)

                VStack(spacing: 8) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                }
                .padding()
            }
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(isSelected ? 0.5 : 0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .disabled(isProcessing)
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    SmartProcessView(unprocessedCount: 47) { _ in }
}