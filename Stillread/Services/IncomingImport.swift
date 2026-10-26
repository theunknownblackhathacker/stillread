// Stillread/Services/IncomingImport.swift

import Foundation

/// Something handed to the app from outside: the Share Extension (stillread://import?…)
/// or a file opened with "Open in Stillread".
enum IncomingImport: Sendable {
    case webPage(URL)
    case text(String, title: String?)
    case file(URL)
    /// The extension put the text on the clipboard because it was too long for a link.
    case pasteboard

    static let scheme = "stillread"

    init?(url: URL) {
        if url.isFileURL {
            self = .file(url)
            return
        }
        guard url.scheme == Self.scheme,
              url.host() == "import",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return nil }

        let value: (String) -> String? = { name in items.first { $0.name == name }?.value }

        if let link = value("url"), let webURL = URL(string: link) {
            self = .webPage(webURL)
        } else if let text = value("text") {
            self = .text(text, title: value("title"))
        } else if value("pasteboard") != nil {
            self = .pasteboard
        } else {
            return nil
        }
    }

    /// A string that is just one http(s) link.
    static func singleWebURL(in string: String) -> URL? {
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
}
