// Stillread/Services/ModelContainerFactory.swift

import Foundation
import SwiftData

/// Creates the SwiftData container. New models and properties migrate automatically.
/// If the store still can't be opened, it is reset rather than crashing on every launch.
enum ModelContainerFactory {
    static let schema = Schema([ReadingText.self, QuizQuestion.self, ReadingSession.self])

    static func make() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            print("SwiftData store failed to open, resetting: \(error)")
            removeStoreFiles(at: configuration.url)
            do {
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("Could not create SwiftData container: \(error)")
            }
        }
    }

    private static func removeStoreFiles(at url: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let file = URL(fileURLWithPath: url.path() + suffix)
            try? fileManager.removeItem(at: file)
        }
    }
}
