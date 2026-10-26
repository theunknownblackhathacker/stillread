// Stillread/Views/ReaderScreen.swift

import SwiftUI
import SwiftData

/// Connects a library text to the reader and the quiz.
/// Saves the reading position whenever playback stops or the screen closes.
struct ReaderScreen: View {
    let text: ReadingText
    let viewModel: ReaderViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var quiz: QuizViewModel?
    @State private var isMakingQuiz = false
    @State private var quizMessage: LocalizedStringResource?

    var body: some View {
        ZStack {
            if let quiz {
                QuizView(viewModel: quiz, onClose: { dismiss() }, onReadAgain: readAgain)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ReaderView(viewModel: viewModel) {
                    finishedPanel
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.5), value: quiz == nil)
        .onChange(of: viewModel.state) {
            savePosition()
        }
        .onDisappear {
            viewModel.pause()
            savePosition()
        }
    }

    // MARK: - Finished panel

    private var finishedPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Finished")
                    .font(.title2.weight(.semibold))
                Text(finishedSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.mode.showsQuiz {
                if !text.questions.isEmpty {
                    PrimaryActionButton(title: "Start quiz", systemImage: "checklist") {
                        startQuiz()
                    }
                } else if canMakeQuiz {
                    PrimaryActionButton(
                        title: isMakingQuiz ? "Writing questions…" : "Make a quiz",
                        systemImage: "sparkles",
                        isLoading: isMakingQuiz
                    ) {
                        makeQuiz()
                    }
                }
            }

            if let quizMessage {
                Text(quizMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            HStack(spacing: 12) {
                SecondaryActionButton(title: "Read again", systemImage: "arrow.counterclockwise") {
                    viewModel.togglePlayback()
                }
                SecondaryActionButton(title: "Close", systemImage: "xmark") {
                    dismiss()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.smooth(duration: 0.35), value: isMakingQuiz)
    }

    private var finishedSubtitle: LocalizedStringKey {
        if !viewModel.mode.showsQuiz {
            return "Flow mode: no quiz, just reading."
        }
        if !text.questions.isEmpty {
            return "\(text.questions.count) questions to check what stayed with you."
        }
        if canMakeQuiz {
            return "Apple Intelligence can write a few questions about this text."
        }
        if text.wordCount > TextGenerator.maxWordsForQuiz {
            return "This text is too long for an on-device quiz."
        }
        return "Quizzes need Apple Intelligence, which isn't available right now."
    }

    private var canMakeQuiz: Bool {
        AIAvailability.current == .available
            && text.wordCount <= TextGenerator.maxWordsForQuiz
            && AIAvailability.supports(languageCode: text.language)
    }

    // MARK: - Actions

    private func startQuiz() {
        quiz = QuizViewModel(questions: text.sortedQuestions, wordsPerMinute: viewModel.wordsPerMinute)
    }

    private func readAgain() {
        quiz = nil
        viewModel.restart()
    }

    /// Quiz for the user's own text (spec §4b).
    private func makeQuiz() {
        guard !isMakingQuiz else { return }
        isMakingQuiz = true
        quizMessage = nil

        let body = text.body
        let count = TextGenerator.quizQuestionCount(forWordCount: text.wordCount)
        let languageName = text.language
            .flatMap { Locale(identifier: "en").localizedString(forLanguageCode: $0) }
            ?? "the same language as the text"

        Task {
            let generator = TextGenerator()
            do {
                let generated = try await generator.writeQuiz(forText: body, languageName: languageName, count: count)
                let questions = TextGenerator.makeQuestions(from: generated, limit: count)
                if questions.isEmpty {
                    quizMessage = "The quiz couldn't be written for this text. Try again."
                } else {
                    text.questions = questions
                    startQuiz()
                }
            } catch {
                quizMessage = TextGenerator.message(for: error)
            }
            isMakingQuiz = false
        }
    }

    private func savePosition() {
        let index = viewModel.savedWordIndex
        if text.lastWordIndex != index {
            text.lastWordIndex = index
        }
    }
}
