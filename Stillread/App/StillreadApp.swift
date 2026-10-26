// Stillread/App/StillreadApp.swift

import SwiftUI
import SwiftData

@main
struct StillreadApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: ReadingText.self)
    }
}
