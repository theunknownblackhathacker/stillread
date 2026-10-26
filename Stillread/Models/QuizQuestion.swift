// Stillread/Models/QuizQuestion.swift

import Foundation
import SwiftData

/// One multiple-choice question, linked to its text (spec data model).
@Model
final class QuizQuestion {
    var question: String
    var options: [String]
    var correctIndex: Int
    /// Display order within the quiz.
    var order: Int
    var text: ReadingText?

    init(question: String, options: [String], correctIndex: Int, order: Int) {
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
        self.order = order
    }
}
