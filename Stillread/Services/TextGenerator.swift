// Stillread/Services/TextGenerator.swift

import Foundation
import FoundationModels

// MARK: - Structured output (spec §4a: @Generable)

@Generable
struct GeneratedArticle {
    @Guide(description: "A short, inviting title of at most six words")
    var title: String

    @Guide(description: "The full text as plain paragraphs separated by one blank line. No headings, lists, markdown or emojis.")
    var body: String
}

@Generable
struct GeneratedQuestion {
    @Guide(description: "A clear question that checks understanding of the text")
    var question: String

    @Guide(description: "Four short answer options. Exactly one is correct.", .count(4))
    var options: [String]

    @Guide(description: "Index of the correct option", .range(0...3))
    var correctIndex: Int
}

@Generable
struct GeneratedQuiz {
    @Guide(description: "Multiple-choice questions about the text", .minimumCount(2), .maximumCount(5))
    var questions: [GeneratedQuestion]
}

// MARK: - Availability

enum AIAvailability: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceOff
    case modelNotReady
    case unknown

    static var current: AIAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .appleIntelligenceOff
            case .modelNotReady: return .modelNotReady
            @unknown default: return .unknown
            }
        @unknown default:
            return .unknown
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .available:
            "Apple Intelligence is ready."
        case .deviceNotEligible:
            "This iPhone doesn't support Apple Intelligence, so texts can't be generated on device."
        case .appleIntelligenceOff:
            "Turn on Apple Intelligence in Settings → Apple Intelligence & Siri to generate texts."
        case .modelNotReady:
            "Apple Intelligence is still downloading. Keep your iPhone on Wi-Fi and charging, then try again."
        case .unknown:
            "Apple Intelligence isn't available right now."
        }
    }

    static func supports(_ language: ReadingLanguage) -> Bool {
        supports(languageCode: language.rawValue)
    }

    /// Unknown language (nil) is allowed; the model will try.
    static func supports(languageCode code: String?) -> Bool {
        guard let code else { return true }
        return SystemLanguageModel.default.supportedLanguages.contains {
            $0.languageCode?.identifier == code
        }
    }
}

// MARK: - Generator

/// Wraps an on-device LanguageModelSession. One generator per generated text:
/// the quiz is written in the same session, so the model still has the text in context.
@MainActor
final class TextGenerator {
    /// On-device context is ~4K tokens, so own texts longer than this can't get a quiz.
    static let maxWordsForQuiz = 1500

    private static let instructions = """
        You write short, original reading texts for a speed-reading app. \
        Write natural, engaging prose in plain paragraphs separated by one blank line. \
        Never use headings, bullet points, markdown, quotes from real people or emojis. \
        When asked for questions, write them in the same language as the text.
        """

    private let session = LanguageModelSession(instructions: TextGenerator.instructions)

    func prewarm() {
        session.prewarm()
    }

    /// Streams the article. `onUpdate` receives the partial title and body as they are written.
    func writeArticle(
        topic: String,
        language: ReadingLanguage,
        level: ReadingLevel,
        length: TextLength,
        onUpdate: (_ title: String?, _ body: String?) -> Void
    ) async throws -> GeneratedArticle {
        let prompt = """
            Write a text in \(language.englishName) about: \(topic).
            Reading level: CEFR \(level.rawValue), \(level.promptDescription).
            Length: about \(length.targetWords) words in \(length.paragraphs) paragraphs.
            """

        let stream = session.streamResponse(
            to: prompt,
            generating: GeneratedArticle.self,
            options: GenerationOptions(temperature: 0.9)
        )

        var latest: GeneratedContent?
        for try await snapshot in stream {
            onUpdate(snapshot.content.title, snapshot.content.body)
            latest = snapshot.rawContent
        }

        guard let latest else { throw TextGeneratorError.emptyResponse }
        return try GeneratedArticle(latest)
    }

    /// Questions about the article this generator just wrote.
    func writeQuizForArticle(count: Int, language: ReadingLanguage) async throws -> [GeneratedQuestion] {
        let prompt = """
            Now write exactly \(count) multiple-choice questions in \(language.englishName) \
            about the main ideas of the text you just wrote. \
            Each question has four short options and exactly one correct answer.
            """
        let response = try await session.respond(to: prompt, generating: GeneratedQuiz.self)
        return response.content.questions
    }

    /// Questions about one of the user's own texts (spec §4b).
    func writeQuiz(forText text: String, languageName: String, count: Int) async throws -> [GeneratedQuestion] {
        let prompt = """
            Here is a text:

            \(text)

            Write exactly \(count) multiple-choice questions in \(languageName) \
            about the main ideas of this text. \
            Each question has four short options and exactly one correct answer.
            """
        let response = try await session.respond(to: prompt, generating: GeneratedQuiz.self)
        return response.content.questions
    }

    // MARK: - Helpers

    /// Converts model output into stored questions. Drops malformed questions and
    /// shuffles options so the correct answer isn't always in the same slot.
    static func makeQuestions(from generated: [GeneratedQuestion], limit: Int) -> [QuizQuestion] {
        var result: [QuizQuestion] = []
        for item in generated {
            guard result.count < limit else { break }
            let question = item.question.trimmingCharacters(in: .whitespacesAndNewlines)
            let options = item.options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard
                !question.isEmpty,
                options.count == 4,
                Set(options).count == 4,
                !options.contains(where: \.isEmpty),
                options.indices.contains(item.correctIndex)
            else { continue }

            let correct = options[item.correctIndex]
            let shuffled = options.shuffled()
            guard let newIndex = shuffled.firstIndex(of: correct) else { continue }
            result.append(
                QuizQuestion(question: question, options: shuffled, correctIndex: newIndex, order: result.count)
            )
        }
        return result
    }

    static func quizQuestionCount(forWordCount words: Int) -> Int {
        switch words {
        case ..<200: 2
        case ..<400: 3
        case ..<700: 4
        default: 5
        }
    }

    /// Friendly message for any generation error.
    static func message(for error: Error) -> LocalizedStringResource {
        if let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .guardrailViolation, .refusal:
                return "Apple Intelligence declined this topic. Try a different one."
            case .exceededContextWindowSize:
                return "This is too long for the on-device model."
            case .unsupportedLanguageOrLocale:
                return "The on-device model doesn't support this language yet."
            case .assetsUnavailable:
                return "Apple Intelligence is still getting ready. Try again in a moment."
            case .rateLimited, .concurrentRequests:
                return "The model is busy. Try again in a moment."
            default:
                return "Something went wrong while writing. Please try again."
            }
        }
        return "Something went wrong while writing. Please try again."
    }
}

enum TextGeneratorError: Error {
    case emptyResponse
}
