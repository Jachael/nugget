import SwiftUI

struct SmartProcessView: View {
    @Environment(\.dismiss) var dismiss
    @State private var customQuery = ""
    @State private var selectedPreset: String?
    @State private var isProcessing = false
    @State private var processingComplete = false
    @State private var errorMessage: String?
    @State private var session: Session?

    let unprocessedCount: Int
    let onSessionCreated: (Session) -> Void

    // Time-based greeting similar to HomeView
    var timeBasedPrompt: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "What do you want to read this morning?"
        } else if hour < 17 {
            return "What do you want to read this afternoon?"
        } else {
            return "What do you want to read this evening?"
        }
    }

    // Preset queries with neutral styling
    let presetQueries = [
        ("Tech This Week", "tech from this week", [Color.primary, Color.secondary]),
        ("Career Insights", "career advice", [Color.primary, Color.secondary]),
        ("Quick Reads", "quick 5 minute reads", [Color.primary, Color.secondary]),
        ("Finance Updates", "finance and markets", [Color.primary, Color.secondary]),
        ("Learn Something", "interesting facts", [Color.primary, Color.secondary]),
        ("Today's Best", "best from today", [Color.primary, Color.secondary])
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Compact Header with time-based greeting
                    VStack(spacing: 4) {
                        Text(timeBasedPrompt)
                            .font(.headline)

                        if unprocessedCount > 0 {
                            Text("\(unprocessedCount) items ready")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Add content to your feed to get started")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 24)

                    // Custom query input
                    if unprocessedCount > 0 {
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Capsule())
                            .glassEffect(.regular, in: .capsule)
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
                                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
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
                                    isProcessing: isProcessing && selectedPreset == query,
                                    isComplete: processingComplete && selectedPreset == query
                                ) {
                                    selectedPreset = query
                                    processQuery(query)
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Show prompt to add content when no unprocessed items
                        VStack(spacing: 16) {
                            Image(systemName: "plus.app")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                                .symbolRenderingMode(.hierarchical)

                            Text("No content available")
                                .font(.headline)

                            Text("Add articles, videos, or links to your feed to start learning")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button {
                                dismiss()
                            } label: {
                                Text("Got it")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .glassEffect(.regular, in: .capsule)
                            }
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
                // Create the smart session
                _ = try await NuggetService.shared.createSmartSession(query: query)

                await MainActor.run {
                    // Show success state
                    withAnimation(.easeInOut(duration: 0.3)) {
                        processingComplete = true
                        isProcessing = false
                    }

                    // Auto-dismiss after a short delay to show confirmation
                    Task {
                        try? await Task.sleep(for: .seconds(0.6))

                        // Dismiss the view
                        dismiss()

                        // Immediately refresh the home view
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshNuggets"), object: nil)
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
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
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                if isComplete {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                        Text("Ready!")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .glassEffect(in: .rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.primary.opacity(0.3), lineWidth: 2)
                    )
                } else if isProcessing {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.secondary)
                            .scaleEffect(0.6)
                        Text("Processing...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
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
        .disabled(isProcessing || isComplete)
        .scaleEffect(isSelected ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}

#Preview {
    SmartProcessView(unprocessedCount: 47) { _ in }
}