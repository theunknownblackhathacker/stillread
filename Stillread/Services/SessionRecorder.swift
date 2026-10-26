// Stillread/Services/SessionRecorder.swift

import Foundation
import SwiftData

/// What the results UI shows after a sitting.
struct SessionResult: Equatable, Sendable {
    var streak: Int
    var isFastestFinish: Bool
    var isBestEffective: Bool
}

/// Saves reading sessions and answers "is this a personal best?".
@MainActor
enum SessionRecorder {
    /// Sittings shorter than this (and not finished) are not saved.
    static let minimumSeconds = 20.0

    static func record(
        text: ReadingText,
        viewModel: ReaderViewModel,
        completed: Bool,
        in context: ModelContext
    ) -> ReadingSession {
        let session = ReadingSession(
            textID: text.id,
            textTitle: text.title,
            mode: viewModel.mode,
            wordsPerMinute: viewModel.wordsPerMinute,
            durationSeconds: viewModel.playedSeconds,
            wordsRead: viewModel.wordsRead,
            completed: completed
        )
        context.insert(session)
        return session
    }

    static func result(for session: ReadingSession, in context: ModelContext) -> SessionResult {
        let all = (try? context.fetch(FetchDescriptor<ReadingSession>())) ?? []
        let others = all.filter { $0.persistentModelID != session.persistentModelID && $0.modeRaw == session.modeRaw }

        // A best only counts when it beats an earlier result in the same mode.
        let previousFastest = others.filter(\.completed).map(\.wordsPerMinute).max()
        let isFastest = session.completed && previousFastest.map { session.wordsPerMinute > $0 } == true

        let previousEffective = others.compactMap(\.effectiveWordsPerMinute).max()
        let isBestEffective = session.effectiveWordsPerMinute.map { current in
            previousEffective.map { current > $0 } == true
        } ?? false

        return SessionResult(
            streak: ProgressCalculator.streak(for: all.map(\.date)).current,
            isFastestFinish: isFastest,
            isBestEffective: isBestEffective
        )
    }
}
