// Stillread/Models/Word.swift

import Foundation

/// One token shown by the RSVP reader.
/// Punctuation flags are captured now so the timing multipliers (Milestone 2)
/// can be added without touching the tokenizer.
struct Word: Identifiable, Hashable, Sendable {
    let id: Int
    let text: String
    let endsClause: Bool
    let endsSentence: Bool
    let endsParagraph: Bool
}
