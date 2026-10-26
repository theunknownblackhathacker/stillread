// Stillread/App/StillreadApp.swift

import SwiftUI
import SwiftData

@main
struct StillreadApp: App {
    private let container = ModelContainerFactory.make()

    @AppStorage(SettingsKey.appearance) private var appearanceRaw = Appearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            HomeView()
                .onAppear { applyAppearance() }
                .onChange(of: appearanceRaw) { applyAppearance() }
        }
        .modelContainer(container)
    }

    private func applyAppearance() {
        (Appearance(rawValue: appearanceRaw) ?? .system).apply()
    }
}
