import SwiftUI
import WebKit

struct TestWebView: View {
    @Environment(\.dismiss) var dismiss
    @State private var webPage = WebPage()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(GlassButtonStyle())
                .padding()

                Spacer()

                Text("Testing WebView")
                    .font(.headline)

                Spacer()

                if webPage.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    Color.clear.frame(width: 80) // Balance the layout
                }
            }
            .glassEffect(in: .rect)

            // Native iOS 26 WebView
            WebView(webPage)
                .onAppear {
                    if let url = URL(string: "https://www.apple.com") {
                        webPage.load(URLRequest(url: url))
                    }
                }
        }
    }
}
