// Stillread/Services/OptimalRecognitionPoint.swift

import Foundation

struct ORPParts: Equatable, Sendable {
    let prefix: String
    let anchor: String
    let suffix: String

    static let empty = ORPParts(prefix: "", anchor: "", suffix: "")
}

/// Finds the anchor letter (spec §1).
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

    /// Single word. Length counts letters/digits only, so "“Hello," anchors on "e".
    static func split(_ word: String) -> ORPParts {
        let characters = Array(word)
        guard !characters.isEmpty else { return .empty }

        let leading = characters.prefix(while: { !isCore($0) }).count
        let trailing = characters.reversed().prefix(while: { !isCore($0) }).count
        let coreLength = characters.count - leading - trailing

        let rawIndex = coreLength > 0 ? leading + index(forLength: coreLength) : 0
        return parts(of: characters, anchorAt: min(rawIndex, characters.count - 1))
    }

    /// Multi-word chunk (Chunk mode): anchor on the letter nearest the middle,
    /// so the eye sits in the centre of the phrase and takes in both sides.
    static func splitPhrase(_ phrase: String) -> ORPParts {
        let characters = Array(phrase)
        guard characters.count > 1 else { return split(phrase) }

        let middle = (characters.count - 1) / 2
        var anchorIndex = middle

        if !isCore(characters[middle]) {
            for offset in 1..<characters.count {
                if middle - offset >= 0, isCore(characters[middle - offset]) {
                    anchorIndex = middle - offset
                    break
                }
                if middle + offset < characters.count, isCore(characters[middle + offset]) {
                    anchorIndex = middle + offset
                    break
                }
            }
        }

        return parts(of: characters, anchorAt: anchorIndex)
    }

    private static func isCore(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }

    private static func parts(of characters: [Character], anchorAt index: Int) -> ORPParts {
        ORPParts(
            prefix: String(characters[..<index]),
            anchor: String(characters[index]),
            suffix: String(characters[(index + 1)...])
        )
    }
}
