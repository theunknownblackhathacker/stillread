// Stillread/Models/GenerationSettings.swift

import Foundation

/// Text languages from spec §8. Names are shown in their own language.
enum ReadingLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case english = "en"
    case ukrainian = "uk"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case portuguese = "pt"
    case italian = "it"
    case polish = "pl"
    case turkish = "tr"

    var id: Self { self }

    var nativeName: String {
        switch self {
        case .english: "English"
        case .ukrainian: "Українська"
        case .german: "Deutsch"
        case .french: "Français"
        case .spanish: "Español"
        case .portuguese: "Português"
        case .italian: "Italiano"
        case .polish: "Polski"
        case .turkish: "Türkçe"
        }
    }

    /// English name, used inside prompts.
    var englishName: String {
        Locale(identifier: "en").localizedString(forLanguageCode: rawValue) ?? rawValue
    }

    /// The device language if we offer it, otherwise English.
    static var deviceDefault: ReadingLanguage {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return ReadingLanguage(rawValue: code) ?? .english
    }
}

/// CEFR levels from spec §4a.
enum ReadingLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"

    var id: Self { self }

    /// Guidance for the model.
    var promptDescription: String {
        switch self {
        case .a1: "very simple: short sentences, the most common everyday words, present tense"
        case .a2: "simple: short sentences, common words, simple past and future"
        case .b1: "intermediate: clear connected sentences, everyday vocabulary with some topic words"
        case .b2: "upper-intermediate: varied sentence structure and a broader vocabulary"
        case .c1: "advanced: rich vocabulary, complex sentences and some nuance"
        }
    }
}

/// Text lengths from spec §4a. Question count follows the 2–5 range in spec §3.
enum TextLength: String, CaseIterable, Identifiable, Codable, Sendable {
    case short
    case medium
    case long

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .short: "Short"
        case .medium: "Medium"
        case .long: "Long"
        }
    }

    var targetWords: Int {
        switch self {
        case .short: 150
        case .medium: 300
        case .long: 500
        }
    }

    var paragraphs: Int {
        switch self {
        case .short: 2
        case .medium: 3
        case .long: 5
        }
    }

    var questionCount: Int {
        switch self {
        case .short: 2
        case .medium: 3
        case .long: 5
        }
    }
}

enum SurpriseTopics {
    static let all = [
        "how octopuses solve problems",
        "the history of the paperclip",
        "why we dream",
        "a lighthouse keeper's ordinary day",
        "how bees choose a new home",
        "the first maps of the world",
        "why cats purr",
        "the science of a perfect cup of coffee",
        "how forests talk through fungi",
        "a short history of the bicycle",
        "why the sky changes colour at sunset",
        "how memory works while we sleep",
        "the invention of the printing press",
        "life on a small island in winter",
        "how migrating birds find their way",
        "the story of the first library",
        "why music gives us chills",
        "how a city wakes up in the morning",
        "the secret life of tardigrades",
        "the history of tea",
        "how volcanoes create new land",
        "a walk through an old night market",
        "why we yawn",
        "how the Olympic Games began",
        "the quiet work of deep-sea explorers",
        "how ancient people measured time",
        "why some foods taste better the next day",
        "the journey of a single raindrop",
        "how elephants remember",
        "the art of Japanese gardens",
    ]

    static func random() -> String {
        all.randomElement() ?? "the ocean"
    }
}
