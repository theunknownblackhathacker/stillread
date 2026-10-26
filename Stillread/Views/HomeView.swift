// Stillread/Views/HomeView.swift

import SwiftUI
import SwiftData
import UIKit

/// Main screen: the library. Each card zooms into the reader (and back) with the
/// system zoom transition, which is interactive and runs at 120 Hz.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    /// Library texts (daily texts live in the Today section and the calendar).
    @Query(filter: #Predicate<ReadingText> { $0.dailyKey == nil }, sort: \ReadingText.createdAt, order: .reverse)
    private var texts: [ReadingText]
    @Query(filter: #Predicate<ReadingText> { $0.dailyKey != nil }, sort: \ReadingText.createdAt, order: .reverse)
    private var dailyTexts: [ReadingText]
    @Query private var sessions: [ReadingSession]
    @AppStorage(SettingsKey.wordsPerMinute) private var wordsPerMinute = ReaderDefaults.wordsPerMinute
    @AppStorage(SettingsKey.language) private var languageRaw = ReadingLanguage.deviceDefault.rawValue
    @AppStorage(SettingsKey.level) private var levelRaw = ReadingLevel.b1.rawValue

    @State private var daily = DailyTextViewModel()
    @State private var now = Date.now
    @State private var refreshTick = 0
    @State private var isShowingSettings = false
    @State private var isShowingCalendar = false

    @State private var openReader: OpenReader?
    @State private var addRequest: AddRequest?
    /// An import that arrived while something else was on screen; shown once that closes.
    @State private var pendingAddRequest: AddRequest?
    @State private var isGenerating = false
    @State private var isShowingProgress = false
    /// Set by the generator's "Read now"; opened once the sheet has finished closing.
    @State private var textToOpen: ReadingText?
    @State private var hasAppeared = false
    @Namespace private var zoom

    private let listAnimation = Animation.smooth(duration: 0.45)
    private let progressID = "progress"
    private let settingsID = "settings"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                    .entrance(hasAppeared, delay: 0)

                todaySection
                    .entrance(hasAppeared, delay: 0.08)

                Group {
                    if texts.isEmpty {
                        emptyState
                            .transition(.opacity)
                    } else {
                        library
                    }
                }
                .entrance(hasAppeared, delay: 0.16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemBackground))
        .fullScreenCover(item: $openReader, onDismiss: presentPendingAddRequest) { reader in
            ReaderScreen(text: reader.text, viewModel: reader.viewModel)
                .navigationTransition(.zoom(sourceID: reader.id, in: zoom))
        }
        .sheet(item: $addRequest, onDismiss: presentPendingAddRequest) { request in
            AddTextView(viewModel: request.viewModel)
        }
        .sheet(isPresented: $isGenerating, onDismiss: {
            openPendingText()
            presentPendingAddRequest()
        }) {
            GenerateTextView { text in
                textToOpen = text
            }
        }
        .sheet(isPresented: $isShowingProgress, onDismiss: presentPendingAddRequest) {
            ProgressScreen()
                .navigationTransition(.zoom(sourceID: progressID, in: zoom))
        }
        .sheet(isPresented: $isShowingSettings, onDismiss: presentPendingAddRequest) {
            SettingsView()
                .navigationTransition(.zoom(sourceID: settingsID, in: zoom))
        }
        .sheet(isPresented: $isShowingCalendar, onDismiss: {
            openPendingText()
            presentPendingAddRequest()
        }) {
            DailyCalendarView(texts: dailyTexts) { text in
                textToOpen = text
                isShowingCalendar = false
            }
        }
        .onOpenURL(perform: handleIncoming)
        .task {
            LibrarySeeder.seedIfNeeded(in: modelContext)
        }
        // Writes today's text if it's missing (new day, or language/level changed in Settings).
        .task(id: "\(todayKey)#\(refreshTick)") {
            daily.ensureToday(
                key: todayKey,
                date: now,
                language: language,
                level: level,
                exists: todayText != nil,
                context: modelContext
            )
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = .now
                refreshTick += 1
            }
        }
        .onAppear { hasAppeared = true }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Stillread")
                        .font(.largeTitle.weight(.bold))
                    Text("Read with a quiet mind.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    CircleIconButton(systemImage: "sparkles", accessibilityLabel: "Generate with AI") {
                        isGenerating = true
                    }
                    CircleIconButton(systemImage: "plus", accessibilityLabel: "Add text") {
                        addRequest = AddRequest(viewModel: AddTextViewModel())
                    }
                    CircleIconButton(systemImage: "gearshape", accessibilityLabel: "Settings") {
                        isShowingSettings = true
                    }
                    .matchedTransitionSource(id: settingsID, in: zoom)
                }
            }

            streakChip
        }
    }

    /// Opens Progress with a zoom from the chip.
    private var streakChip: some View {
        let streak = ProgressCalculator.streak(for: sessions.map(\.date)).current

        return Button {
            isShowingProgress = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(streak > 0 ? Color.orange : Color.secondary)
                Text(streakTitle(streak))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemBackground), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressableCardStyle())
        .matchedTransitionSource(id: progressID, in: zoom)
        .accessibilityLabel(Text("Progress"))
        .accessibilityValue(Text(streakTitle(streak)))
    }

    private func streakTitle(_ streak: Int) -> LocalizedStringKey {
        streak > 0 ? "\(streak)-day streak" : "Start a streak today"
    }

    // MARK: - Today (spec §5)

    private var language: ReadingLanguage { ReadingLanguage(rawValue: languageRaw) ?? .deviceDefault }
    private var level: ReadingLevel { ReadingLevel(rawValue: levelRaw) ?? .b1 }
    private var todayKey: String { DailyText.key(for: now, language: language, level: level) }
    private var todayText: ReadingText? { dailyTexts.first { $0.dailyKey == todayKey } }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    isShowingCalendar = true
                } label: {
                    Label("Calendar", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if let today = todayText {
                Button {
                    open(today)
                } label: {
                    LibraryCard(text: today, wordsPerMinute: wordsPerMinute, eyebrow: dailyEyebrow)
                }
                .buttonStyle(PressableCardStyle())
                .matchedTransitionSource(id: today.id, in: zoom)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                DailyStatusCard(model: daily) {
                    daily.retry(key: todayKey, date: now, language: language, level: level, context: modelContext)
                }
                .transition(.opacity)
            }
        }
        .animation(listAnimation, value: todayText?.id)
        .animation(listAnimation, value: daily.status)
    }

    private var dailyEyebrow: String {
        [String(localized: "Daily text"), language.nativeName, level.rawValue].joined(separator: " · ")
    }

    private var library: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            Text("Library")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(texts) { text in
                Button {
                    open(text)
                } label: {
                    LibraryCard(text: text, wordsPerMinute: wordsPerMinute)
                }
                .buttonStyle(PressableCardStyle())
                .matchedTransitionSource(id: text.id, in: zoom)
                .contextMenu {
                    if text.lastWordIndex > 0 {
                        Button {
                            withAnimation(listAnimation) { text.lastWordIndex = 0 }
                        } label: {
                            Label("Start over", systemImage: "arrow.counterclockwise")
                        }
                    }
                    Button(role: .destructive) {
                        withAnimation(listAnimation) { modelContext.delete(text) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(listAnimation, value: texts.map(\.id))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.page")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)

            Text("Your library is empty")
                .font(.title3.weight(.semibold))

            Text("Generate a text with AI, or add an article, a PDF or a scanned page you want to read faster.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                PrimaryActionButton(title: "Generate with AI", systemImage: "sparkles") {
                    isGenerating = true
                }
                SecondaryActionButton(title: "Add your own text", systemImage: "plus") {
                    addRequest = AddRequest(viewModel: AddTextViewModel())
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Incoming imports (Share Extension, "Open in Stillread")

    private func handleIncoming(_ url: URL) {
        guard let incoming = IncomingImport(url: url) else { return }
        let request = AddRequest(viewModel: AddTextViewModel())
        let model = request.viewModel

        switch incoming {
        case .webPage(let webURL):
            model.importWebPage(webURL)
        case .text(let text, let title):
            model.receiveShared(text, title: title)
        case .file(let fileURL):
            model.importFile(at: fileURL)
        case .pasteboard:
            if let string = UIPasteboard.general.string {
                model.receiveShared(string)
            }
        }

        let somethingIsOpen = openReader != nil || addRequest != nil || isGenerating
            || isShowingProgress || isShowingSettings || isShowingCalendar
        if somethingIsOpen {
            pendingAddRequest = request
            openReader = nil
            addRequest = nil
            isGenerating = false
            isShowingProgress = false
            isShowingSettings = false
            isShowingCalendar = false
        } else {
            addRequest = request
        }
    }

    private func presentPendingAddRequest() {
        guard let request = pendingAddRequest else { return }
        pendingAddRequest = nil
        addRequest = request
    }

    private func openPendingText() {
        guard let text = textToOpen else { return }
        textToOpen = nil
        open(text)
    }

    private func open(_ text: ReadingText) {
        let viewModel = ReaderViewModel(title: text.title, text: text.body, startWord: text.lastWordIndex)
        openReader = OpenReader(text: text, viewModel: viewModel)
    }
}

/// One "New text" sheet with its own view model, so imports can start before it appears.
private struct AddRequest: Identifiable {
    let id = UUID()
    let viewModel: AddTextViewModel
}

/// The text being read plus its reader state. Created once per opening,
/// so the text is only tokenized when the reader actually opens.
private struct OpenReader: Identifiable {
    let text: ReadingText
    let viewModel: ReaderViewModel
    var id: UUID { text.id }
}

// MARK: - Card

private struct LibraryCard: View {
    let text: ReadingText
    let wordsPerMinute: Int
    /// Small line above the title, e.g. "Daily text · English · B1".
    var eyebrow: String?

    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .textCase(.uppercase)
            }

            Text(text.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(text.excerpt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if text.isInProgress {
                ReadingProgressBar(value: text.progress)
                    .transition(.opacity)
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: text.source.symbolName)
                        Text(text.source.label)
                        Text(verbatim: "·")
                        Text(text.createdAt, format: .dateTime.day().month(.abbreviated))
                    }
                    Text("\(text.wordCount) words · ~\(text.estimatedMinutes(atWordsPerMinute: wordsPerMinute)) min")
                        .monospacedDigit()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Label(actionTitle, systemImage: text.isFinished ? "arrow.counterclockwise" : "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .foregroundStyle(Color(.systemBackground))
                    .background(Color.primary, in: Capsule())
                    .fixedSize()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: shape)
        .contentShape(shape)
        .animation(.smooth(duration: 0.45), value: text.lastWordIndex)
    }

    private var actionTitle: LocalizedStringKey {
        if text.isFinished { return "Read again" }
        if text.isInProgress { return "Continue" }
        return "Read"
    }
}

// MARK: - Daily status (writing / unavailable / failed)

private struct DailyStatusCard: View {
    let model: DailyTextViewModel
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch model.status {
            case .idle, .writing:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Writing today's text…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if !model.streamedTitle.isEmpty {
                    Text(model.streamedTitle)
                        .font(.title3.weight(.semibold))
                        .transition(.opacity)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach([1.0, 0.92, 0.6], id: \.self) { width in
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scaleEffect(x: width, anchor: .leading)
                    }
                }
                .phaseAnimator([0.45, 1.0]) { content, phase in
                    content.opacity(phase)
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }

            case .unavailable:
                Label {
                    Text(model.message ?? "Daily texts need Apple Intelligence.")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

            case .failed:
                Text(model.message ?? "Today's text couldn't be written.")
                    .font(.subheadline)
                SecondaryActionButton(title: "Try again", systemImage: "arrow.clockwise", action: retry)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(.smooth(duration: 0.4), value: model.streamedTitle)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: ReadingText.self, inMemory: true)
}
