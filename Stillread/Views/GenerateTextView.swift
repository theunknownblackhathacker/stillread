// Stillread/Views/GenerateTextView.swift

import SwiftUI
import SwiftData

/// Sheet for generating a text on device with Apple Intelligence (spec §4a).
/// The text streams in as it is written; when done it is saved with its quiz.
struct GenerateTextView: View {
    /// Called with the saved text when the user taps "Read now".
    let onRead: (ReadingText) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = GenerateTextViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                switch viewModel.phase {
                case .setup, .failed:
                    setupForm
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .writing, .writingQuiz, .done:
                    writingView
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.smooth(duration: 0.45), value: viewModel.phase)
            .background(Color(.systemBackground))
            .navigationTitle("New AI text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.phase == .done ? "Close" : "Cancel") {
                        viewModel.cancel()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isBusy)
        .onAppear {
            viewModel.attach(modelContext)
            viewModel.refreshAvailability()
        }
        .onDisappear { viewModel.cancel() }
    }

    // MARK: - Setup

    private var setupForm: some View {
        @Bindable var viewModel = viewModel

        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if viewModel.availability != .available {
                    NoticeCard(systemImage: "sparkles", message: viewModel.availability.message)
                }

                section("Topic") {
                    HStack(spacing: 10) {
                        TextField("e.g. how bees choose a home", text: $viewModel.topic)
                            .submitLabel(.go)
                            .onSubmit { viewModel.generate() }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        CircleIconButton(systemImage: "dice", accessibilityLabel: "Surprise me", size: 50) {
                            withAnimation(.smooth(duration: 0.3)) { viewModel.surpriseTopic() }
                        }
                    }
                    Text("Leave it empty and we'll surprise you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                section("Length") {
                    Picker("Length", selection: $viewModel.length) {
                        ForEach(TextLength.allCases) { length in
                            Text(length.title).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("About \(viewModel.length.targetWords) words · \(viewModel.length.questionCount) quiz questions")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }

                section("Level") {
                    Picker("Level", selection: $viewModel.level) {
                        ForEach(ReadingLevel.allCases) { level in
                            Text(verbatim: level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                section("Language") {
                    Picker("Language", selection: $viewModel.language) {
                        ForEach(ReadingLanguage.allCases) { language in
                            if viewModel.supportedLanguages.contains(language) {
                                Text(verbatim: language.nativeName).tag(language)
                            } else {
                                Text("\(language.nativeName) (not on device)").tag(language)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if viewModel.availability == .available, !viewModel.isLanguageSupported {
                        Text("The on-device model doesn't support \(viewModel.language.nativeName) yet. Pick another language.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = viewModel.errorMessage {
                    NoticeCard(systemImage: "exclamationmark.triangle", message: error)
                        .transition(.opacity)
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            PrimaryActionButton(
                title: "Write my text",
                systemImage: "sparkles",
                isEnabled: viewModel.canGenerate
            ) {
                viewModel.generate()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(Color(.systemBackground))
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    // MARK: - Writing / done

    private var writingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    if viewModel.isBusy {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Text(statusText)
                        .contentTransition(.opacity)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .animation(.smooth(duration: 0.3), value: viewModel.phase)

                Text(viewModel.streamedTitle.isEmpty ? " " : viewModel.streamedTitle)
                    .font(.title.weight(.bold))

                Text(viewModel.streamedBody)
                    .font(.body)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let note = viewModel.quizNote {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .safeAreaInset(edge: .bottom) {
            if viewModel.phase == .done, let text = viewModel.savedText {
                PrimaryActionButton(title: "Read now", systemImage: "play.fill") {
                    onRead(text)
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var statusText: LocalizedStringKey {
        switch viewModel.phase {
        case .writingQuiz: "Writing quiz questions…"
        case .done: "Saved to your library"
        default: "Writing…"
        }
    }
}

private struct NoticeCard: View {
    let systemImage: String
    let message: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
