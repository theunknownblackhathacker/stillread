// Stillread/ViewModels/DailyTextViewModel.swift

import Foundation
import Observation
import SwiftData

/// Writes today's text in the background when it doesn't exist yet (spec §5).
/// The text is saved like any other, with a `dailyKey`, so it is cached for good.
@MainActor
@Observable
final class DailyTextViewModel {
    enum Status: Equatable {
        case idle
        case writing
        case unavailable
        case failed
    }

    private(set) var status: Status = .idle
    private(set) var message: LocalizedStringResource?
    private(set) var streamedTitle = ""

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var writingKey: String?
    @ObservationIgnored private var modelContext: ModelContext?

    /// Starts writing today's text unless it already exists or is being written.
    func ensureToday(key: String, date: Date, language: ReadingLanguage, level: ReadingLevel, exists: Bool, context: ModelContext) {
        guard !exists else {
            if writingKey != key { status = .idle }
            return
        }
        guard writingKey != key || status == .failed else { return }

        let availability = AIAvailability.current
        guard availability == .available else {
            task?.cancel()
            writingKey = nil
            status = .unavailable
            message = availability.message
            return
        }
        guard AIAvailability.supports(language) else {
            task?.cancel()
            writingKey = nil
            status = .unavailable
            message = "Daily texts need a language Apple Intelligence supports. Change it in Settings."
            return
        }

        task?.cancel()
        modelContext = context
        writingKey = key
        status = .writing
        message = nil
        streamedTitle = ""

        task = Task { [weak self] in
            await self?.write(key: key, date: date, language: language, level: level)
        }
    }

    func retry(key: String, date: Date, language: ReadingLanguage, level: ReadingLevel, context: ModelContext) {
        status = .failed
        ensureToday(key: key, date: date, language: language, level: level, exists: false, context: context)
    }

    private func write(key: String, date: Date, language: ReadingLanguage, level: ReadingLevel) async {
        let generator = TextGenerator()
        let length = TextLength.medium

        do {
            let article = try await generator.writeArticle(
                topic: SurpriseTopics.topic(for: date),
                language: language,
                level: level,
                length: length
            ) { [weak self] title, _ in
                self?.streamedTitle = GenerateTextViewModel.cleanTitle(title ?? "")
            }
            try Task.checkCancellation()

            var questions: [QuizQuestion] = []
            if let generated = try? await generator.writeQuizForArticle(count: length.questionCount, language: language) {
                questions = TextGenerator.makeQuestions(from: generated, limit: length.questionCount)
            }
            try Task.checkCancellation()

            let title = GenerateTextViewModel.cleanTitle(article.title)
            let text = ReadingText(
                title: title.isEmpty ? String(localized: "Today's text") : title,
                body: GenerateTextViewModel.cleanBody(article.body),
                source: .ai,
                language: language.rawValue,
                level: level.rawValue
            )
            text.dailyKey = key
            modelContext?.insert(text)
            text.questions = questions

            status = .idle
            writingKey = nil
        } catch is CancellationError {
            // A newer request (other language/level or day) replaced this one.
        } catch {
            status = .failed
            message = TextGenerator.message(for: error)
            writingKey = nil
        }
    }
}
