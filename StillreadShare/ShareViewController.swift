// StillreadShare/ShareViewController.swift

import UIKit
import UniformTypeIdentifiers

/// Share Extension: receives a web page link or selected text and hands it to the app
/// with a stillread://import link. No App Group needed, so it works with any signing setup.
/// If the app can't be opened from here, the content is copied to the clipboard instead.
final class ShareViewController: UIViewController {
    /// Longer text goes through the clipboard instead of the link.
    private static let maxTextInLink = 30_000

    private let spinner = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private var didStart = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        spinner.startAnimating()

        statusLabel.text = String(localized: "Sending to Stillread…")
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center

        var configuration = UIButton.Configuration.filled()
        configuration.title = String(localized: "Done")
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = .label
        configuration.baseForegroundColor = .systemBackground
        doneButton.configuration = configuration
        doneButton.isHidden = true
        doneButton.addAction(UIAction { [weak self] _ in self?.finish() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [spinner, statusLabel, doneButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        Task { await handleSharedItems() }
    }

    // MARK: - Flow

    private func handleSharedItems() async {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        var sharedURL: URL?
        var sharedText: String?

        for provider in providers {
            if sharedURL == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let url = await loadURL(from: provider), !url.isFileURL {
                sharedURL = url
            }
            if sharedText == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let text = await loadText(from: provider),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sharedText = text
            }
        }

        // Some apps share a link as plain text.
        if sharedURL == nil, let text = sharedText, let url = Self.singleWebURL(in: text) {
            sharedURL = url
            sharedText = nil
        }

        let link: URL?
        let fallback: String?

        if let sharedURL {
            // A page from Safari: the app fetches and extracts the article itself.
            link = Self.importLink(["url": sharedURL.absoluteString])
            fallback = sharedURL.absoluteString
        } else if let sharedText {
            if sharedText.count <= Self.maxTextInLink {
                link = Self.importLink(["text": sharedText])
            } else {
                UIPasteboard.general.string = sharedText
                link = Self.importLink(["pasteboard": "1"])
            }
            fallback = sharedText
        } else {
            link = nil
            fallback = nil
        }

        guard let link else {
            showMessage(String(localized: "There's nothing here Stillread can read."))
            return
        }

        if openMainApp(link) {
            try? await Task.sleep(for: .milliseconds(400))
            finish()
        } else {
            if let fallback { UIPasteboard.general.string = fallback }
            showMessage(String(localized: "Copied. Open Stillread, tap + and then Paste."))
        }
    }

    private func showMessage(_ message: String) {
        spinner.stopAnimating()
        spinner.isHidden = true
        statusLabel.text = message
        doneButton.isHidden = false
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    // MARK: - Opening the app

    /// Extensions can't call UIApplication.open directly, so walk the responder chain to the
    /// application object and call `openURL:options:completionHandler:` through the
    /// Objective-C runtime.
    private func openMainApp(_ url: URL) -> Bool {
        typealias OpenURLFunction = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
        let selector = NSSelectorFromString("openURL:options:completionHandler:")

        var responder: UIResponder? = self
        while let current = responder {
            if current is UIApplication, current.responds(to: selector), let implementation = current.method(for: selector) {
                let open = unsafeBitCast(implementation, to: OpenURLFunction.self)
                open(current, selector, url as NSURL, NSDictionary(), nil)
                return true
            }
            responder = current.next
        }
        return false
    }

    private static func importLink(_ parameters: [String: String]) -> URL? {
        // Encode everything except unreserved characters, so "&", "=" and "+" survive.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let query = parameters
            .map { key, value in
                "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
            }
            .joined(separator: "&")
        return URL(string: "stillread://import?\(query)")
    }

    private static func singleWebURL(in string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: \.isWhitespace),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host() != nil
        else { return nil }
        return url
    }

    // MARK: - Loading shared items

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                continuation.resume(returning: text)
            }
        }
    }
}
