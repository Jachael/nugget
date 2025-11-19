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
                VStack(spacing: 20) {
                    // Compact Header
                    VStack(spacing: 4) {
                        Text("What do you want to learn?")
                            .font(.headline)

                        Text("\(unprocessedCount) items ready")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 12)

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
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    // Preset queries grid - 3 columns for compact layout
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 10) {
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
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
            .presentationDetents([.fraction(0.65)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
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

                    // Dismiss the sheet first
                    dismiss()

                    // Then navigate to the session after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSessionCreated(newSession)
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
            VStack(spacing: 0) {
                if isProcessing {
                    ProgressView()
                        .tint(.secondary)
                        .scaleEffect(0.7)
                        .frame(height: 60)
                        .frame(maxWidth: .infinity)
                        .glassEffect(in: .rect(cornerRadius: 12))
                } else {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .glassEffect(in: .rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    LinearGradient(gradient: Gradient(colors: gradientColors),
                                                 startPoint: .topLeading,
                                                 endPoint: .bottomTrailing),
                                    lineWidth: isSelected ? 2 : 0
                                )
                        )
                }
            }
        }
        .disabled(isProcessing)
        .scaleEffect(isSelected ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}

#Preview {
    SmartProcessView(unprocessedCount: 47) { _ in }
}