// Stillread/Models/ReadingMode.swift

import Foundation

/// Reading modes from spec §2.
enum ReadingMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case standard
    case ramp
    case chunk
    case flow

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .standard: "Standard"
        case .ramp: "Ramp"
        case .chunk: "Chunk"
        case .flow: "Flow"
        }
    }

    var summary: LocalizedStringResource {
        switch self {
        case .standard: "Steady speed from start to finish."
        case .ramp: "Starts slower and speeds up to your target."
        case .chunk: "Two or three words at a time."
        case .flow: "Relaxed reading. No quiz afterwards."
        }
    }

    /// Whether a comprehension quiz follows the text (used from Milestone 4).
    var showsQuiz: Bool { self != .flow }
}
