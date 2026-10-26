// Stillread/App/StillreadApp.swift

import SwiftUI
import SwiftData

@main
struct StillreadApp: App {
    private let container = ModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(container)
    }
}
