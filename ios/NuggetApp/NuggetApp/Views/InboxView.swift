import SwiftUI

struct InboxView: View {
    @State private var nuggets: [Nugget] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddNugget = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            loadNuggets()
                        }
                    }
                    .padding()
                } else if nuggets.isEmpty {
                    emptyStateView
                } else {
                    List(nuggets) { nugget in
                        NuggetRowView(nugget: nugget)
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddNugget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddNugget) {
                AddNuggetView { nugget in
                    nuggets.insert(nugget, at: 0)
                }
            }
            .onAppear {
                if nuggets.isEmpty {
                    loadNuggets()
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No nuggets yet")
                .font(.title3)
            Text("Tap + to save your first piece of content")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func loadNuggets() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let loadedNuggets = try await NuggetService.shared.listNuggets()
                await MainActor.run {
                    nuggets = loadedNuggets
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load nuggets: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct NuggetRowView: View {
    let nugget: Nugget

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = nugget.title {
                Text(title)
                    .font(.headline)
            }

            if let summary = nugget.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                Text("Processing...")
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.secondary)
            }

            HStack {
                if let category = nugget.category {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }

                Spacer()

                Text(nugget.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddNuggetView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (Nugget) -> Void

    @State private var url = ""
    @State private var title = ""
    @State private var category = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Content") {
                    TextField("URL", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)

                    TextField("Title (optional)", text: $title)
                }

                Section("Organization") {
                    TextField("Category (optional)", text: $category)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Nugget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNugget()
                    }
                    .disabled(url.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveNugget() {
        isSaving = true
        errorMessage = nil

        let request = CreateNuggetRequest(
            sourceUrl: url,
            sourceType: "url",
            rawTitle: title.isEmpty ? nil : title,
            rawText: nil,
            category: category.isEmpty ? nil : category
        )

        Task {
            do {
                let nugget = try await NuggetService.shared.createNugget(request: request)
                await MainActor.run {
                    onSave(nugget)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}
