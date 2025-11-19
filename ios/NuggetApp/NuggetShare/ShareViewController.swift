import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private var sharedURL: URL?
    private var containerView: UIView!
    private var activityIndicator: UIActivityIndicatorView!
    private var successImageView: UIImageView!
    private var titleLabel: UILabel!
    private var messageLabel: UILabel!
    private var actionStackView: UIStackView!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        extractURL()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)

        // Container for the content
        containerView = UIView()
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 20
        containerView.layer.masksToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Activity indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        containerView.addSubview(activityIndicator)

        // Success image (hidden initially)
        successImageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        successImageView.tintColor = .systemGreen
        successImageView.contentMode = .scaleAspectFit
        successImageView.translatesAutoresizingMaskIntoConstraints = false
        successImageView.alpha = 0
        containerView.addSubview(successImageView)

        // Title label
        titleLabel = UILabel()
        titleLabel.text = "Saving to Nugget..."
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // Message label
        messageLabel = UILabel()
        messageLabel.text = "Adding to your inbox"
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(messageLabel)

        // Action buttons stack (hidden initially)
        actionStackView = UIStackView()
        actionStackView.axis = .vertical
        actionStackView.spacing = 12
        actionStackView.distribution = .fillEqually
        actionStackView.translatesAutoresizingMaskIntoConstraints = false
        actionStackView.alpha = 0
        containerView.addSubview(actionStackView)

        // Setup constraints
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 280),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),

            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),

            successImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            successImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            successImageView.widthAnchor.constraint(equalToConstant: 60),
            successImageView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            actionStackView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            actionStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            actionStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            actionStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }

    private func extractURL() {
        // Extract the URL from the share context
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            print("No input items or attachments found")
            showError(NSError(domain: "ShareExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: "No content to share"]))
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
                        self?.showError(NSError(domain: "ShareExtension", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to extract URL"]))
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
                            self?.showError(NSError(domain: "ShareExtension", code: 3, userInfo: [NSLocalizedDescriptionKey: "No valid URL found"]))
                        }
                    } else {
                        print("Failed to extract text: \(String(describing: error))")
                        self?.showError(NSError(domain: "ShareExtension", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to process content"]))
                    }
                }
                return
            }
        }

        print("No compatible attachment type found")
        showError(NSError(domain: "ShareExtension", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unsupported content type"]))
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
        if let sharedDefaults = UserDefaults(suiteName: "group.erg.NuggetApp") {
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
        } else {
            print("Failed to access shared UserDefaults")
            showError(NSError(domain: "ShareExtension", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to save content"]))
            return
        }

        DispatchQueue.main.async {
            self.showSuccess(for: url)
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
        let urlString = url.absoluteString.lowercased()
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

    private func showSuccess(for url: URL) {
        // Animate the success state
        UIView.animate(withDuration: 0.3, animations: {
            self.activityIndicator.alpha = 0
        }) { _ in
            self.activityIndicator.stopAnimating()

            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
                self.successImageView.alpha = 1
                self.successImageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }) { _ in
                UIView.animate(withDuration: 0.2) {
                    self.successImageView.transform = .identity
                }
            }
        }

        titleLabel.text = "Saved!"
        messageLabel.text = "Article added to your Nugget inbox"

        // Show action buttons
        setupActionButtons(for: url)

        UIView.animate(withDuration: 0.3, delay: 0.2, options: [], animations: {
            self.actionStackView.alpha = 1
        }, completion: nil)
    }

    private func setupActionButtons(for url: URL) {
        // Add and Process Now button
        let processButton = createActionButton(title: "Process Now", style: .primary) { [weak self] in
            self?.processNow()
        }
        actionStackView.addArrangedSubview(processButton)

        // View in App button
        let viewButton = createActionButton(title: "View in App", style: .secondary) { [weak self] in
            self?.openInApp()
        }
        actionStackView.addArrangedSubview(viewButton)

        // Done button
        let doneButton = createActionButton(title: "Done", style: .tertiary) { [weak self] in
            self?.dismiss()
        }
        actionStackView.addArrangedSubview(doneButton)
    }

    private func createActionButton(title: String, style: ButtonStyle, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: style == .primary ? .semibold : .medium)
        button.layer.cornerRadius = 12
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true

        switch style {
        case .primary:
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
        case .secondary:
            button.backgroundColor = .secondarySystemFill
            button.setTitleColor(.label, for: .normal)
        case .tertiary:
            button.backgroundColor = .clear
            button.setTitleColor(.secondaryLabel, for: .normal)
        }

        button.addAction(UIAction { _ in action() }, for: .touchUpInside)

        return button
    }

    private enum ButtonStyle {
        case primary, secondary, tertiary
    }

    private func processNow() {
        // Mark the nugget for immediate processing
        if let sharedDefaults = UserDefaults(suiteName: "group.erg.NuggetApp") {
            sharedDefaults.set(true, forKey: "processImmediately")
            sharedDefaults.synchronize()
        }

        // Open the app to process
        openInApp()
    }

    private func openInApp() {
        // Open the main app
        if let url = URL(string: "nuggetapp://inbox") {
            extensionContext?.open(url, completionHandler: { [weak self] success in
                if success {
                    self?.dismiss()
                } else {
                    // If custom URL scheme fails, just dismiss
                    self?.dismiss()
                }
            })
        } else {
            dismiss()
        }
    }

    private func dismiss() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func showError(_ error: Error) {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.activityIndicator.alpha = 0

            self.titleLabel.text = "Error"
            self.messageLabel.text = error.localizedDescription

            // Show only Done button for errors
            let doneButton = self.createActionButton(title: "OK", style: .primary) { [weak self] in
                self?.dismiss()
            }
            self.actionStackView.addArrangedSubview(doneButton)

            UIView.animate(withDuration: 0.3) {
                self.actionStackView.alpha = 1
            }
        }
    }
}