// Stillread/ViewModels/AddTextViewModel.swift

import Foundation
import NaturalLanguage
import Observation

@MainActor
@Observable
final class AddTextViewModel {
    static let autoTitleWordLimit = 6

    var title = ""
    var body = ""

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var wordCount: Int {
        trimmedBody.split(whereSeparator: \.isWhitespace).count
    }

    var canSave: Bool { wordCount > 0 }

    /// Pasting into an empty editor replaces it; otherwise adds a new paragraph.
    func paste(_ strings: [String]) {
        let pasted = strings
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pasted.isEmpty else { return }
        body = trimmedBody.isEmpty ? pasted : trimmedBody + "\n\n" + pasted
    }

    func makeText() -> ReadingText? {
        let cleaned = trimmedBody
        guard !cleaned.isEmpty else { return nil }
        let language = NLLanguageRecognizer.dominantLanguage(for: String(cleaned.prefix(2000)))
        return ReadingText(
            title: resolvedTitle(for: cleaned),
            body: cleaned,
            source: .paste,
            language: language?.rawValue
        )
    }

    /// The typed title, or the first few words of the text.
    private func resolvedTitle(for text: String) -> String {
        let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }

        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let allWords = firstLine.split(whereSeparator: \.isWhitespace)
        let words = allWords.prefix(Self.autoTitleWordLimit)
        var result = words.joined(separator: " ")

        if allWords.count > Self.autoTitleWordLimit {
            while let last = result.last, last.isPunctuation {
                result.removeLast()
            }
            result += "…"
        }
        return result
    }
}
