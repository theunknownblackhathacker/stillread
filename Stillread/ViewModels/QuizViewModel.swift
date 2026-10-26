// Stillread/ViewModels/QuizViewModel.swift

import Foundation
import Observation

struct QuizItem: Identifiable, Equatable, Sendable {
    let id: Int
    let question: String
    let options: [String]
    let correctIndex: Int
}

@MainActor
@Observable
final class QuizViewModel {
    let items: [QuizItem]
    let wordsPerMinute: Int

    private(set) var currentIndex = 0
    private(set) var selectedOption: Int?
    private(set) var correctCount = 0
    private(set) var wrongCount = 0
    private(set) var isFinished = false

    init(questions: [QuizQuestion], wordsPerMinute: Int) {
        items = questions.enumerated().map { index, question in
            QuizItem(
                id: index,
                question: question.question,
                options: question.options,
                correctIndex: question.correctIndex
            )
        }
        self.wordsPerMinute = wordsPerMinute
    }

    var current: QuizItem? {
        items.indices.contains(currentIndex) ? items[currentIndex] : nil
    }

    var hasAnswered: Bool { selectedOption != nil }

    var isLastQuestion: Bool { currentIndex >= items.count - 1 }

    var answeredCount: Int { correctCount + wrongCount }

    var accuracy: Double {
        items.isEmpty ? 0 : Double(correctCount) / Double(items.count)
    }

    /// Spec §3: effective wpm = wpm × accuracy.
    var effectiveWordsPerMinute: Int {
        Int((Double(wordsPerMinute) * accuracy).rounded())
    }

    func select(_ option: Int) {
        guard selectedOption == nil, let current else { return }
        selectedOption = option
        if option == current.correctIndex {
            correctCount += 1
        } else {
            wrongCount += 1
        }
    }

    func next() {
        guard hasAnswered else { return }
        if isLastQuestion {
            isFinished = true
        } else {
            currentIndex += 1
            selectedOption = nil
        }
    }
}
