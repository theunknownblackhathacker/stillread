// Stillread/Services/TextCleaner.swift

import Foundation

/// Turns hard-wrapped text (PDFs, .txt files, scanned pages) into clean paragraphs
/// separated by blank lines, which is what the tokenizer uses for paragraph pauses.
enum TextCleaner {
    private static let paragraphEnders: Set<Character> = [".", "!", "?", "…", ":", "\"", "”", "»", ")"]

    static func reflow(_ raw: String) -> String {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{00AD}", with: "")   // soft hyphen

        let lines = normalized
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let nonEmpty = lines.filter { !$0.isEmpty }
        let lengths = nonEmpty.map(\.count).sorted()
        guard !lengths.isEmpty else { return "" }
        let typical = lengths[Int(Double(lengths.count - 1) * 0.75)]
        let endingShare = Double(nonEmpty.filter { $0.last.map(paragraphEnders.contains) ?? false }.count)
            / Double(nonEmpty.count)

        // Lines are already whole paragraphs (not hard-wrapped): keep them as they are.
        // Hard-wrapped prose has long lines and few of them end a sentence.
        if typical > 150 || endingShare > 0.6 {
            return lines.filter { !$0.isEmpty && !isPageNumber($0) }.joined(separator: "\n\n")
        }

        var paragraphs: [String] = []
        var current = ""

        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { paragraphs.append(trimmed) }
            current = ""
        }

        for line in lines {
            if line.isEmpty {
                flush()
                continue
            }
            if isPageNumber(line) { continue }

            if current.isEmpty {
                current = line
            } else if current.hasSuffix("-"), let first = line.first, first.isLowercase {
                // Word broken across lines: "under-" + "stand" → "understand".
                current.removeLast()
                current += line
            } else {
                current += " " + line
            }

            // A short line that ends a sentence usually ends the paragraph.
            if let last = line.last, paragraphEnders.contains(last), Double(line.count) < Double(typical) * 0.7 {
                flush()
            }
        }
        flush()

        return paragraphs.joined(separator: "\n\n")
    }

    private static func isPageNumber(_ line: String) -> Bool {
        let stripped = line.trimmingCharacters(in: CharacterSet(charactersIn: "-–— "))
        if !stripped.isEmpty, stripped.count <= 4, stripped.allSatisfy(\.isNumber) { return true }
        let lower = stripped.lowercased()
        return lower.hasPrefix("page ")
            && lower.count < 16
            && lower.dropFirst(5).allSatisfy { $0.isNumber || $0 == " " || $0 == "/" }
    }
}
