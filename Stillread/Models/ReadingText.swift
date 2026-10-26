// Stillread/Models/ReadingText.swift

import Foundation
import SwiftData

/// A saved text in the library (spec data model).
@Model
final class ReadingText {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    /// Raw value of `TextSource`. Stored as a string so it is easy to filter on later.
    var sourceRaw: String
    /// BCP-47 code, e.g. "en". Detected for pasted texts.
    var language: String?
    /// CEFR level ("A1"…"C1") for AI texts; nil for own texts.
    var level: String?
    var createdAt: Date
    /// First word of the frame to resume from. Equal to `wordCount` when finished.
    var lastWordIndex: Int
    var wordCount: Int
    @Relationship(deleteRule: .cascade, inverse: \QuizQuestion.text)
    var questions: [QuizQuestion] = []

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        source: TextSource,
        language: String? = nil,
        level: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.sourceRaw = source.rawValue
        self.language = language
        self.level = level
        self.createdAt = createdAt
        self.lastWordIndex = 0
        self.wordCount = Tokenizer.words(from: body).count
    }

    var source: TextSource {
        TextSource(rawValue: sourceRaw) ?? .paste
    }

    var sortedQuestions: [QuizQuestion] {
        questions.sorted { $0.order < $1.order }
    }

    var isFinished: Bool {
        wordCount > 0 && lastWordIndex >= wordCount
    }

    var isInProgress: Bool {
        lastWordIndex > 0 && !isFinished
    }

    var progress: Double {
        guard wordCount > 0 else { return 0 }
        return min(Double(lastWordIndex) / Double(wordCount), 1)
    }

    /// First ~200 characters on one line, for library cards.
    var excerpt: String {
        let start = body.prefix(200)
        return start.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Rough reading time including punctuation pauses (~20% on typical prose).
    func estimatedMinutes(atWordsPerMinute wpm: Int) -> Int {
        guard wpm > 0 else { return 0 }
        let remaining = isFinished ? wordCount : wordCount - lastWordIndex
        return max(1, Int((Double(remaining) / Double(wpm) * 1.2).rounded()))
    }
}
