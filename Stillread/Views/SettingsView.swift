// Stillread/Views/SettingsView.swift

import SwiftUI
import UIKit

/// Settings (spec §9). Everything is stored in UserDefaults and applies immediately.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage(SettingsKey.wordsPerMinute) private var wordsPerMinute = ReaderDefaults.wordsPerMinute
    @AppStorage(SettingsKey.font) private var fontRaw = ReaderFont.system.rawValue
    @AppStorage(SettingsKey.textSize) private var textSize = TextSizeSetting.defaultValue
    @AppStorage(SettingsKey.anchorColor) private var anchorColorRaw = AnchorColor.red.rawValue
    @AppStorage(SettingsKey.hapticTick) private var hapticTick = false
    @AppStorage(SettingsKey.appearance) private var appearanceRaw = Appearance.system.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = ReadingLanguage.deviceDefault.rawValue
    @AppStorage(SettingsKey.level) private var levelRaw = ReadingLevel.b1.rawValue

    @State private var supportedLanguages: Set<ReadingLanguage> = []

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                readingSection
                textSection
                appearanceSection
                languageSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .animation(.smooth(duration: 0.3), value: fontRaw)
            .animation(.smooth(duration: 0.3), value: anchorColorRaw)
        }
        .onAppear {
            supportedLanguages = Set(ReadingLanguage.allCases.filter { AIAvailability.supports($0) })
        }
    }

    // MARK: - Sections

    private var previewSection: some View {
        Section {
            RSVPWordView(
                parts: OptimalRecognitionPoint.split(String(localized: "reading")),
                fontScale: textSize,
                anchorColor: anchorColor.color,
                fontDesign: font
            )
            .frame(height: 120)
            .listRowInsets(EdgeInsets())
            .padding(.vertical, 8)
        } footer: {
            Text("Preview of the reader with your settings.")
        }
    }

    private var readingSection: some View {
        Section("Reading") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Default speed")
                    Spacer()
                    Text("\(wordsPerMinute) wpm")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Slider(
                    value: Binding(
                        get: { Double(wordsPerMinute) },
                        set: { wordsPerMinute = Int($0.rounded()) }
                    ),
                    in: 100...1000,
                    step: 10
                )
                .tint(.primary)
                .accessibilityLabel(Text("Default speed"))
            }
            .padding(.vertical, 4)

            Toggle(isOn: $hapticTick) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Haptic tick")
                    Text("A light tap on every word.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var textSection: some View {
        Section("Text") {
            Picker("Font", selection: $fontRaw) {
                ForEach(ReaderFont.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Size")
                    Spacer()
                    Text(textSize, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $textSize, in: TextSizeSetting.range, step: 0.1)
                    .tint(.primary)
                    .accessibilityLabel(Text("Size"))
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("Anchor colour")
                HStack(spacing: 14) {
                    ForEach(AnchorColor.allCases) { option in
                        Button {
                            anchorColorRaw = option.rawValue
                        } label: {
                            Circle()
                                .fill(option.color)
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if option == anchorColor {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary.opacity(option == anchorColor ? 0.35 : 0), lineWidth: 2)
                                        .padding(-4)
                                )
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityLabel(Text(option.title))
                        .accessibilityAddTraits(option == anchorColor ? .isSelected : [])
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Appearance", selection: $appearanceRaw) {
                ForEach(Appearance.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var languageSection: some View {
        Section {
            Picker("Text language", selection: $languageRaw) {
                ForEach(ReadingLanguage.allCases) { language in
                    if supportedLanguages.contains(language) {
                        Text(verbatim: language.nativeName).tag(language.rawValue)
                    } else {
                        Text("\(language.nativeName) (not on device)").tag(language.rawValue)
                    }
                }
            }

            Picker("Level", selection: $levelRaw) {
                ForEach(ReadingLevel.allCases) { level in
                    Text(verbatim: level.rawValue).tag(level.rawValue)
                }
            }
            .pickerStyle(.segmented)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                HStack {
                    Text("App language")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(currentAppLanguage)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("Language")
        } footer: {
            Text("Text language and level are used for AI texts and the daily text. The app language is changed in iOS Settings: English, Ελληνικά, Shqip, Español, Русский or Italiano.")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(verbatim: appVersion)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var font: ReaderFont { ReaderFont(rawValue: fontRaw) ?? .system }
    private var anchorColor: AnchorColor { AnchorColor(rawValue: anchorColorRaw) ?? .red }

    private var currentAppLanguage: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return ReadingLanguage(rawValue: code)?.nativeName
            ?? Locale.current.localizedString(forLanguageCode: code)
            ?? code
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}

/// Defaults shared by Settings and Home (literal values so they can be used in property wrappers).
enum ReaderDefaults {
    static let wordsPerMinute = 350
}

#Preview {
    SettingsView()
}
