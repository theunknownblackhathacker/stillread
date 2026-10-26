// Stillread/Models/ReadingSession.swift

import Foundation
import SwiftData

/// One sitting with a text (spec data model "Session").
/// Kept even if the text is later deleted, so history and streaks stay intact.
@Model
final class ReadingSession {
    var date: Date
    var textID: UUID
    var textTitle: String
    var modeRaw: String
    /// The speed setting used (target speed in Ramp mode).
    var wordsPerMinute: Int
    var score: Int
    var totalQuestions: Int
    /// Time actually spent playing, pauses excluded.
    var durationSeconds: Double
    var wordsRead: Int
    /// True when the text was read to the end in this sitting.
    var completed: Bool

    init(
        date: Date = .now,
        textID: UUID,
        textTitle: String,
        mode: ReadingMode,
        wordsPerMinute: Int,
        durationSeconds: Double,
        wordsRead: Int,
        completed: Bool
    ) {
        self.date = date
        self.textID = textID
        self.textTitle = textTitle
        self.modeRaw = mode.rawValue
        self.wordsPerMinute = wordsPerMinute
        self.score = 0
        self.totalQuestions = 0
        self.durationSeconds = durationSeconds
        self.wordsRead = wordsRead
        self.completed = completed
    }

    var mode: ReadingMode {
        ReadingMode(rawValue: modeRaw) ?? .standard
    }

    var hasQuiz: Bool { totalQuestions > 0 }

    var accuracy: Double? {
        hasQuiz ? Double(score) / Double(totalQuestions) : nil
    }

    /// Spec §3: wpm × accuracy. Nil when no quiz was taken.
    var effectiveWordsPerMinute: Int? {
        accuracy.map { Int((Double(wordsPerMinute) * $0).rounded()) }
    }
}
