// Stillread/Services/LibrarySeeder.swift

import Foundation
import SwiftData

/// Adds the welcome text once, on first launch. If the user deletes it, it stays deleted.
@MainActor
enum LibrarySeeder {
    private static let didSeedKey = "library.didSeedSample"

    static func seedIfNeeded(in context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didSeedKey) else { return }

        context.insert(
            ReadingText(title: SampleText.title, body: SampleText.body, source: .sample, language: "en")
        )
        defaults.set(true, forKey: didSeedKey)
    }
}
