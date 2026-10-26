// Stillread/Views/ReaderScreen.swift

import SwiftUI
import SwiftData

/// Connects a library text to the reader and the quiz.
/// Saves the reading position whenever playback stops, and records a session
/// when the text is finished (or when the screen closes after ≥ 20 s of reading).
struct ReaderScreen: View {
    let text: ReadingText
    let viewModel: ReaderViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var quiz: QuizViewModel?
    @State private var isMakingQuiz = false
    @State private var quizMessage: LocalizedStringResource?
    /// The session for this sitting, once it has been recorded.
    @State private var session: ReadingSession?
    @State private var result: SessionResult?

    var body: some View {
        ZStack {
            if let quiz {
                QuizView(viewModel: quiz, result: result, onClose: { dismiss() }, onReadAgain: readAgain)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ReaderView(viewModel: viewModel) {
                    finishedPanel
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.5), value: quiz == nil)
        .onChange(of: viewModel.state) { oldState, newState in
            savePosition()
            if newState == .finished {
                finishSitting()
            } else if oldState == .finished {
                startNewSitting()
            }
        }
        .onChange(of: quiz?.isFinished ?? false) { _, isFinished in
            if isFinished { recordQuizResult() }
        }
        .onDisappear {
            viewModel.pause()
            savePosition()
            closeSitting()
        }
    }

    // MARK: - Finished panel (results for this sitting)

    private var finishedPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Finished")
                    .font(.title2.weight(.semibold))

                if let session {
                    Text("\(session.wordsRead) words · \(durationText(session.durationSeconds)) · \(session.wordsPerMinute) wpm")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                }

                Text(finishedSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let result, result.streak > 0 || result.isFastestFinish {
                HStack(spacing: 10) {
                    if result.streak > 0 {
                        BadgeView(systemImage: "flame.fill", title: "\(result.streak)-day streak")
                    }
                    if result.isFastestFinish {
                        BadgeView(systemImage: "star.fill", title: "Fastest finish", tint: .yellow)
                    }
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
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
        .animation(.smooth(duration: 0.45), value: result)
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

    private func durationText(_ seconds: Double) -> String {
        Duration.seconds(Int(seconds.rounded())).formatted(.time(pattern: .minuteSecond))
    }

    // MARK: - Sessions

    private func finishSitting() {
        guard session == nil else { return }
        let recorded = SessionRecorder.record(text: text, viewModel: viewModel, completed: true, in: modelContext)
        session = recorded
        result = SessionRecorder.result(for: recorded, in: modelContext)
    }

    private func startNewSitting() {
        session = nil
        result = nil
        viewModel.resetSittingStats()
    }

    /// Partial reading still counts toward the streak and history if it lasted long enough.
    private func closeSitting() {
        guard session == nil, viewModel.playedSeconds >= SessionRecorder.minimumSeconds else { return }
        session = SessionRecorder.record(text: text, viewModel: viewModel, completed: false, in: modelContext)
    }

    private func recordQuizResult() {
        guard let quiz, let session else { return }
        session.score = quiz.correctCount
        session.totalQuestions = quiz.items.count
        result = SessionRecorder.result(for: session, in: modelContext)
    }

    // MARK: - Quiz

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
