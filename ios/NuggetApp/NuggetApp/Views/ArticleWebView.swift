import SwiftUI
import WebKit

struct ArticleWebView: View {
    let url: URL
    let title: String?
    @Environment(\.dismiss) var dismiss
    @State private var webPage = WebPage()
    @State private var hasLoaded = false

    var body: some View {
        VStack(spacing: 0) {
            // Custom top bar with Liquid Glass
            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(GlassButtonStyle())

                VStack(spacing: 2) {
                    if !webPage.title.isEmpty {
                        Text(webPage.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    } else if let title = title, !title.isEmpty {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    Text(url.host ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if webPage.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(GlassButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassEffect(in: .rect)

            // Native iOS 26 WebView with optimized loading
            WebView(webPage)
                .onAppear {
                    // Load on appear with optimized settings
                    if !hasLoaded {
                        hasLoaded = true
                        Task {
                            var request = URLRequest(url: url)
                            request.cachePolicy = .returnCacheDataElseLoad
                            request.timeoutInterval = 30

                            // Add memory-efficient headers
                            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
                            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

                            await MainActor.run { @MainActor in
                                webPage.load(request)
                            }
                        }
                    }
                }
                .onDisappear {
                    // Clean up WebView resources when dismissing
                    webPage.stopLoading()
                }
        }
    }
}
