// Stillread/Models/Word.swift

import Foundation

/// One token of the text being read.
struct Word: Identifiable, Hashable, Sendable {
    let id: Int
    let text: String
    /// Letters and digits only — used for the long-word timing rule (spec §1).
    let letterCount: Int
    let endsClause: Bool
    let endsSentence: Bool
    let endsParagraph: Bool
}
