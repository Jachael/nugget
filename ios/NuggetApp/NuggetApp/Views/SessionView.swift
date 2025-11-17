import SwiftUI

struct SessionView: View {
    let session: Session
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex = 0
    @State private var completedNuggetIds: [String] = []
    @State private var isCompleting = false

    var body: some View {
        ZStack {
            if currentIndex < session.nuggets.count {
                NuggetCardView(
                    nugget: session.nuggets[currentIndex],
                    onComplete: {
                        markAsComplete()
                    },
                    onSkip: {
                        skipNugget()
                    }
                )
            } else {
                sessionCompleteView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Exit") {
                    completeSession()
                }
            }
        }
    }

    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Session Complete!")
                .font(.title.bold())

            Text("You reviewed \(completedNuggetIds.count) nugget\(completedNuggetIds.count == 1 ? "" : "s")")
                .foregroundColor(.secondary)

            Button {
                completeSession()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
    }

    private func markAsComplete() {
        completedNuggetIds.append(session.nuggets[currentIndex].nuggetId)
        nextNugget()
    }

    private func skipNugget() {
        nextNugget()
    }

    private func nextNugget() {
        currentIndex += 1
    }

    private func completeSession() {
        isCompleting = true

        Task {
            do {
                _ = try await NuggetService.shared.completeSession(
                    sessionId: session.sessionId,
                    completedNuggetIds: completedNuggetIds
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}

struct NuggetCardView: View {
    let nugget: Nugget
    let onComplete: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let title = nugget.title {
                    Text(title)
                        .font(.title2.bold())
                }

                if let summary = nugget.summary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(summary)
                    }
                }

                if let keyPoints = nugget.keyPoints, !keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key Points")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        ForEach(keyPoints, id: \.self) { point in
                            HStack(alignment: .top) {
                                Text("•")
                                Text(point)
                            }
                        }
                    }
                }

                if let question = nugget.question {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reflect")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(question)
                            .italic()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        onSkip()
                    } label: {
                        Text("Skip")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }

                    Button {
                        onComplete()
                    } label: {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
}
