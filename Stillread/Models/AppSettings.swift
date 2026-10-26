// Stillread/Models/AppSettings.swift

import SwiftUI
import UIKit

/// UserDefaults keys for settings (spec §9). Views read them with @AppStorage.
enum SettingsKey {
    static let wordsPerMinute = "reader.wordsPerMinute"
    static let mode = "reader.mode"
    static let font = "reader.font"
    static let textSize = "reader.textSize"
    static let anchorColor = "reader.anchorColor"
    static let hapticTick = "reader.hapticTick"
    static let appearance = "app.appearance"
    static let language = "reading.language"
    static let level = "reading.level"
}

enum ReaderFont: String, CaseIterable, Identifiable, Sendable {
    case system
    case serif
    case rounded
    case mono

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .system: "Default"
        case .serif: "Serif"
        case .rounded: "Rounded"
        case .mono: "Mono"
        }
    }

    var design: Font.Design {
        switch self {
        case .system: .default
        case .serif: .serif
        case .rounded: .rounded
        case .mono: .monospaced
        }
    }

    var uiDesign: UIFontDescriptor.SystemDesign {
        switch self {
        case .system: .default
        case .serif: .serif
        case .rounded: .rounded
        case .mono: .monospaced
        }
    }
}

enum AnchorColor: String, CaseIterable, Identifiable, Sendable {
    case red
    case orange
    case blue
    case green
    case purple

    var id: Self { self }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .blue: .blue
        case .green: .green
        case .purple: .purple
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .red: "Red"
        case .orange: "Orange"
        case .blue: "Blue"
        case .green: "Green"
        case .purple: "Purple"
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Applied to every window, so sheets and full-screen covers follow too,
    /// and switching back to System works without a relaunch.
    @MainActor
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }
}

/// Text size multiplier on top of Dynamic Type.
enum TextSizeSetting {
    static let range: ClosedRange<Double> = 0.8...1.5
    static let defaultValue = 1.0
}
