// Stillread/Services/WebArticleExtractor.swift

import Foundation

/// Fetches a web page and pulls out its readable text (title + paragraphs),
/// for pages shared from Safari (spec §4b). Plain Foundation, no third-party parser.
enum WebArticleExtractor {
    private static let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    @concurrent
    static func fetch(_ url: URL) async throws -> ImportedText {
        var secureURL = url
        if url.scheme == "http", var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.scheme = "https"
            secureURL = components.url ?? url
        }

        var request = URLRequest(url: secureURL, timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<400).contains(http.statusCode) {
            throw ImportError.network
        }

        let html = decode(data, encodingName: response.textEncodingName)
        return try extract(from: html, fallbackTitle: url.host())
    }

    static func extract(from html: String, fallbackTitle: String?) throws -> ImportedText {
        let title = metaTitle(in: html) ?? firstMatch(#"(?is)<title[^>]*>(.*?)</title>"#, in: html).map(cleanInline)

        var body = removeBlocks(in: html)
        // Prefer the <article> element when the page has one.
        if let article = firstMatch(#"(?is)<article\b[^>]*>(.*)</article>"#, in: body) {
            body = article
        }

        let paragraphs = allMatches(#"(?is)<p\b[^>]*>(.*?)</p>"#, in: body)
            .map(cleanInline)
            .filter { $0.count >= 25 }

        let text = paragraphs.joined(separator: "\n\n")
        guard text.split(whereSeparator: \.isWhitespace).count >= 40 else {
            throw ImportError.noArticle
        }

        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ImportedText(
            title: (cleanTitle?.isEmpty == false ? cleanTitle : nil) ?? fallbackTitle,
            text: text,
            source: .share
        )
    }

    // MARK: - HTML helpers

    private static func decode(_ data: Data, encodingName: String?) -> String {
        if let encodingName {
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(encodingName as CFString)
            if cfEncoding != kCFStringEncodingInvalidId {
                let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
                if let string = String(data: data, encoding: encoding) { return string }
            }
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func metaTitle(in html: String) -> String? {
        let patterns = [
            #"(?is)<meta[^>]+property=["']og:title["'][^>]*content=["']([^"']+)["']"#,
            #"(?is)<meta[^>]+content=["']([^"']+)["'][^>]*property=["']og:title["']"#,
        ]
        for pattern in patterns {
            if let match = firstMatch(pattern, in: html) {
                return decodeEntities(match)
            }
        }
        return nil
    }

    /// Drops scripts, styles, navigation and other page chrome before looking for paragraphs.
    private static func removeBlocks(in html: String) -> String {
        var result = html
        for tag in ["script", "style", "noscript", "nav", "header", "footer", "aside", "form", "figure", "svg"] {
            result = replace(#"(?is)<\#(tag)\b[^>]*>.*?</\#(tag)>"#, in: result, with: " ")
        }
        return replace(#"(?s)<!--.*?-->"#, in: result, with: " ")
    }

    /// Strips tags, decodes entities and collapses whitespace.
    private static func cleanInline(_ fragment: String) -> String {
        var text = replace(#"(?i)<br\s*/?>"#, in: fragment, with: " ")
        text = replace(#"<[^>]+>"#, in: text, with: "")
        text = decodeEntities(text)
        return text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "mdash": "—", "ndash": "–", "hellip": "…", "rsquo": "’", "lsquo": "‘",
        "rdquo": "”", "ldquo": "“", "laquo": "«", "raquo": "»", "copy": "©", "shy": "",
    ]

    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&"),
              let regex = try? NSRegularExpression(pattern: "&(#[xX]?[0-9a-fA-F]+|[a-zA-Z]+);")
        else { return text }

        let ns = text as NSString
        var result = ""
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let entity = ns.substring(with: match.range(at: 1))
            result += decodeEntity(entity) ?? ns.substring(with: match.range)
            cursor = match.range.location + match.range.length
        }
        result += ns.substring(from: cursor)
        return result
    }

    private static func decodeEntity(_ entity: String) -> String? {
        if entity.hasPrefix("#") {
            let digits = entity.dropFirst()
            let value: UInt32?
            if digits.first == "x" || digits.first == "X" {
                value = UInt32(digits.dropFirst(), radix: 16)
            } else {
                value = UInt32(digits)
            }
            guard let value, let scalar = Unicode.Scalar(value) else { return nil }
            return String(Character(scalar))
        }
        return namedEntities[entity.lowercased()]
    }

    // MARK: - Regex helpers (NSRegularExpression is fast on large pages)

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func allMatches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func replace(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }
}
