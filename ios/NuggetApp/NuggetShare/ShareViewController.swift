import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private var sharedURL: URL?
    private var containerView: UIView!
    private var checkmarkImageView: UIImageView!
    private var titleLabel: UILabel!
    private var messageLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        extractURL()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        // Modern card container
        containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 12
        containerView.layer.shadowOpacity = 0.1
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Success checkmark
        checkmarkImageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmarkImageView.tintColor = .systemGreen
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.alpha = 0
        checkmarkImageView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        containerView.addSubview(checkmarkImageView)

        // Title label
        titleLabel = UILabel()
        titleLabel.text = "Adding to Nugget..."
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // Message label
        messageLabel = UILabel()
        messageLabel.text = "This will appear in your inbox"
        messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.alpha = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(messageLabel)

        // Setup constraints
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            checkmarkImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            checkmarkImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 56),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.topAnchor.constraint(equalTo: checkmarkImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
        ])
    }

    private func extractURL() {
        // Extract the URL from the share context
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            print("No input items or attachments found")
            showError(message: "No content to share")
            return
        }

        // Try to find a URL attachment
        for attachment in attachments {
            // Try public.url first
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                    if let url = item as? URL {
                        self?.sharedURL = url
                        self?.handleSharedURL(url)
                    } else if let urlString = item as? String, let url = URL(string: urlString) {
                        self?.sharedURL = url
                        self?.handleSharedURL(url)
                    } else {
                        print("Failed to extract URL from attachment: \(String(describing: error))")
                        self?.showError(message: "Failed to extract URL")
                    }
                }
                return
            }
            // Try text that might contain a URL
            else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                    if let text = item as? String {
                        // Try to extract URL from text
                        if let url = self?.extractURLFromText(text) {
                            self?.sharedURL = url
                            self?.handleSharedURL(url)
                        } else {
                            print("No valid URL found in text")
                            self?.showError(message: "No valid URL found")
                        }
                    } else {
                        print("Failed to extract text: \(String(describing: error))")
                        self?.showError(message: "Failed to process content")
                    }
                }
                return
            }
        }

        print("No compatible attachment type found")
        showError(message: "Unsupported content type")
    }

    private func extractURLFromText(_ text: String) -> URL? {
        // Try to find URL in text using regex
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

        if let firstMatch = matches?.first, let url = firstMatch.url {
            return url
        }

        // If no URL found with detector, try direct conversion
        if let url = URL(string: text), url.scheme != nil {
            return url
        }

        return nil
    }

    private func handleSharedURL(_ url: URL) {
        // Save to shared UserDefaults using app group
        guard let sharedDefaults = UserDefaults(suiteName: "group.erg.NuggetApp") else {
            print("Failed to access shared UserDefaults")
            showError(message: "Failed to save content")
            return
        }

        // Get existing saved URLs or create new array
        var savedURLs = sharedDefaults.array(forKey: "pendingNuggets") as? [[String: Any]] ?? []

        // Extract title from the page if possible
        let title = extractTitle(from: url)

        // Create nugget data with more details
        var nuggetData: [String: Any] = [
            "url": url.absoluteString,
            "title": title,
            "createdAt": Date().timeIntervalSince1970,
            "id": UUID().uuidString,
            "sourceType": "share_extension"
        ]

        // Add category if available
        if let category = categorizeURL(url) {
            nuggetData["category"] = category
        }

        // Add to array
        savedURLs.append(nuggetData)

        // Save back to shared defaults
        sharedDefaults.set(savedURLs, forKey: "pendingNuggets")
        sharedDefaults.synchronize()

        print("Saved URL to shared storage: \(url)")

        DispatchQueue.main.async {
            self.showSuccess()
        }
    }

    private func extractTitle(from url: URL) -> String {
        // Try to extract a meaningful title from the URL
        if let host = url.host {
            // Clean up the host name
            let cleanHost = host.replacingOccurrences(of: "www.", with: "")
                              .replacingOccurrences(of: ".com", with: "")
                              .replacingOccurrences(of: ".org", with: "")
                              .capitalized

            // Get the last path component if available
            let path = url.lastPathComponent
            if !path.isEmpty && path != "/" {
                return "\(cleanHost): \(path.replacingOccurrences(of: "-", with: " ").capitalized)"
            }

            return cleanHost
        }

        return "Shared Link"
    }

    private func categorizeURL(_ url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""

        // LinkedIn
        if host.contains("linkedin") {
            return "professional"
        }

        // Twitter/X
        if host.contains("twitter") || host.contains("x.com") {
            return "social"
        }

        // News sites
        if host.contains("nytimes") || host.contains("wsj") || host.contains("reuters") ||
           host.contains("bbc") || host.contains("cnn") || host.contains("theguardian") {
            return "news"
        }

        // Tech sites
        if host.contains("github") || host.contains("stackoverflow") || host.contains("medium") ||
           host.contains("dev.to") || host.contains("hackernews") || host.contains("techcrunch") {
            return "technology"
        }

        // Video platforms
        if host.contains("youtube") || host.contains("vimeo") {
            return "video"
        }

        return nil
    }

    private func showSuccess() {
        // Animate the success state
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            self.checkmarkImageView.alpha = 1
            self.checkmarkImageView.transform = .identity
        })

        titleLabel.text = "Saved!"

        UIView.animate(withDuration: 0.3, delay: 0.1, options: [], animations: {
            self.messageLabel.alpha = 1
        })

        // Auto-dismiss after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.dismiss()
        }
    }

    private func showError(message: String) {
        DispatchQueue.main.async {
            self.titleLabel.text = "Oops!"
            self.messageLabel.text = message
            self.messageLabel.alpha = 1

            // Show error icon
            self.checkmarkImageView.image = UIImage(systemName: "xmark.circle.fill")
            self.checkmarkImageView.tintColor = .systemRed

            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
                self.checkmarkImageView.alpha = 1
                self.checkmarkImageView.transform = .identity
            })

            // Auto-dismiss after longer delay for errors
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.dismiss()
            }
        }
    }

    private func dismiss() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
