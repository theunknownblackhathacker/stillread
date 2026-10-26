// Stillread/Services/OptimalRecognitionPoint.swift

import Foundation

struct ORPParts: Equatable, Sendable {
    let prefix: String
    let anchor: String
    let suffix: String
}

/// Finds the anchor letter of a word (spec §1).
/// Length is measured on the letters/digits only, so "I," or "“Hello" anchor on a letter.
enum OptimalRecognitionPoint {
    static func index(forLength length: Int) -> Int {
        switch length {
        case ...1: 0
        case 2...5: 1
        case 6...9: 2
        case 10...13: 3
        default: 4
        }
    }

    static func split(_ word: String) -> ORPParts {
        let characters = Array(word)
        guard !characters.isEmpty else {
            return ORPParts(prefix: "", anchor: "", suffix: "")
        }

        let isCore: (Character) -> Bool = { $0.isLetter || $0.isNumber }
        let leading = characters.prefix(while: { !isCore($0) }).count
        let trailing = characters.reversed().prefix(while: { !isCore($0) }).count
        let coreLength = characters.count - leading - trailing

        let rawIndex = coreLength > 0 ? leading + index(forLength: coreLength) : 0
        let anchorIndex = min(rawIndex, characters.count - 1)

        return ORPParts(
            prefix: String(characters[..<anchorIndex]),
            anchor: String(characters[anchorIndex]),
            suffix: String(characters[(anchorIndex + 1)...])
        )
    }
}
