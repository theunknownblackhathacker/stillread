// Stillread/Services/Tokenizer.swift

import Foundation

/// Splits raw text into `Word` tokens and records punctuation / paragraph boundaries.
enum Tokenizer {
    private static let closingCharacters: Set<Character> = ["\"", "”", "’", "'", ")", "]", "}", "»"]
    private static let sentenceEnders: Set<Character> = [".", "!", "?", "…"]
    private static let clauseEnders: Set<Character> = [",", ";", ":", "—", "–"]

    static func words(from text: String) -> [Word] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let paragraphs = normalized.split(separator: /\n\s*\n/)

        var result: [Word] = []

        for paragraph in paragraphs {
            let tokens = paragraph.split(whereSeparator: \.isWhitespace)
            for (offset, token) in tokens.enumerated() {
                let mark = trailingMark(of: token)
                result.append(
                    Word(
                        id: result.count,
                        text: String(token),
                        endsClause: mark.map { clauseEnders.contains($0) } ?? false,
                        endsSentence: mark.map { sentenceEnders.contains($0) } ?? false,
                        endsParagraph: offset == tokens.count - 1
                    )
                )
            }
        }

        return result
    }

    /// Last meaningful character, ignoring closing quotes and brackets ("end." → ".").
    private static func trailingMark(of token: Substring) -> Character? {
        var trimmed = token
        while let last = trimmed.last, closingCharacters.contains(last) {
            trimmed = trimmed.dropLast()
        }
        return trimmed.last
    }
}
