// Stillread/ViewModels/GenerateTextViewModel.swift

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class GenerateTextViewModel {
    enum Phase: Equatable {
        case setup
        case writing
        case writingQuiz
        case done
        case failed
    }

    var topic = ""
    var language: ReadingLanguage
    var level: ReadingLevel
    var length: TextLength

    private(set) var phase: Phase = .setup
    private(set) var availability: AIAvailability = .unknown
    private(set) var supportedLanguages: Set<ReadingLanguage> = []
    private(set) var streamedTitle = ""
    private(set) var streamedBody = ""
    private(set) var errorMessage: LocalizedStringResource?
    private(set) var quizNote: LocalizedStringResource?
    private(set) var savedText: ReadingText?

    @ObservationIgnored private var generator = TextGenerator()
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var modelContext: ModelContext?

    private enum Keys {
        static let language = "reading.language"
        static let level = "reading.level"
        static let length = "generator.length"
    }

    init() {
        let defaults = UserDefaults.standard
        language = defaults.string(forKey: Keys.language).flatMap(ReadingLanguage.init(rawValue:)) ?? .deviceDefault
        level = defaults.string(forKey: Keys.level).flatMap(ReadingLevel.init(rawValue:)) ?? .b1
        length = defaults.string(forKey: Keys.length).flatMap(TextLength.init(rawValue:)) ?? .medium
    }

    // MARK: - Derived

    var isBusy: Bool { phase == .writing || phase == .writingQuiz }

    var isLanguageSupported: Bool { supportedLanguages.contains(language) }

    var canGenerate: Bool {
        availability == .available && isLanguageSupported && !isBusy
    }

    // MARK: - Lifecycle

    func attach(_ context: ModelContext) {
        modelContext = context
    }

    func refreshAvailability() {
        availability = AIAvailability.current
        supportedLanguages = Set(ReadingLanguage.allCases.filter { AIAvailability.supports($0) })
        if availability == .available {
            generator.prewarm()
        }
    }

    func surpriseTopic() {
        var next = SurpriseTopics.random()
        while next == topic, SurpriseTopics.all.count > 1 {
            next = SurpriseTopics.random()
        }
        topic = next
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    // MARK: - Generation

    func generate() {
        guard canGenerate else { return }
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let chosenTopic = trimmed.isEmpty ? SurpriseTopics.random() : trimmed

        let defaults = UserDefaults.standard
        defaults.set(language.rawValue, forKey: Keys.language)
        defaults.set(level.rawValue, forKey: Keys.level)
        defaults.set(length.rawValue, forKey: Keys.length)

        streamedTitle = ""
        streamedBody = ""
        errorMessage = nil
        quizNote = nil
        savedText = nil
        phase = .writing

        // A fresh session per text, so earlier texts don't leak into the context.
        generator = TextGenerator()
        task = Task { [weak self] in
            await self?.run(topic: chosenTopic)
        }
    }

    private func run(topic: String) async {
        let language = language
        let level = level
        let length = length

        do {
            let article = try await generator.writeArticle(
                topic: topic,
                language: language,
                level: level,
                length: length
            ) { [weak self] title, body in
                self?.streamedTitle = Self.cleanTitle(title ?? "")
                self?.streamedBody = body ?? ""
            }
            try Task.checkCancellation()

            let title = Self.cleanTitle(article.title)
            let body = Self.cleanBody(article.body)
            streamedTitle = title
            streamedBody = body
            phase = .writingQuiz

            var questions: [QuizQuestion] = []
            do {
                let generated = try await generator.writeQuizForArticle(count: length.questionCount, language: language)
                questions = TextGenerator.makeQuestions(from: generated, limit: length.questionCount)
                if questions.isEmpty {
                    quizNote = "The quiz couldn't be written for this text."
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                quizNote = "The quiz couldn't be written for this text."
            }
            try Task.checkCancellation()

            let text = ReadingText(
                title: title.isEmpty ? String(localized: "Untitled") : title,
                body: body,
                source: .ai,
                language: language.rawValue,
                level: level.rawValue
            )
            modelContext?.insert(text)
            text.questions = questions
            savedText = text
            phase = .done
        } catch is CancellationError {
            phase = .setup
        } catch {
            errorMessage = TextGenerator.message(for: error)
            phase = .failed
        }
    }

    // MARK: - Cleanup of model output

    static func cleanTitle(_ title: String) -> String {
        var result = title
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let quotes: Set<Character> = ["\"", "“", "”", "«", "»", "'"]
        while let first = result.first, quotes.contains(first) { result.removeFirst() }
        while let last = result.last, quotes.contains(last) || last == "." { result.removeLast() }
        return result
    }

    /// Every non-empty line becomes a paragraph, separated by a blank line,
    /// which is what the tokenizer uses for paragraph pauses.
    static func cleanBody(_ body: String) -> String {
        body
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .joined(separator: "\n\n")
    }
}
