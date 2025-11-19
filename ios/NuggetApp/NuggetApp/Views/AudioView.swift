import SwiftUI

struct AudioView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "waveform")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color.purple.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(
                                color: Color.purple.opacity(0.3),
                                radius: 20,
                                x: 0,
                                y: 10
                            )

                        Text("Audio Nuggets")
                            .font(.title.bold())

                        Text("Coming soon")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))

                    Spacer()
                }
                .padding(.horizontal)
            }
            .navigationTitle("Audio")
        }
    }
}

#Preview {
    AudioView()
}
