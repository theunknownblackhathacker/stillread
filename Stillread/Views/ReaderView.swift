// Stillread/Views/ReaderView.swift

import SwiftUI

struct ReaderView<FinishedPanel: View>: View {
    let viewModel: ReaderViewModel
    /// Shown at the bottom once the text is finished (quiz, read again, close).
    @ViewBuilder let finishedPanel: () -> FinishedPanel

    init(viewModel: ReaderViewModel, @ViewBuilder finishedPanel: @escaping () -> FinishedPanel) {
        self.viewModel = viewModel
        self.finishedPanel = finishedPanel
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(SettingsKey.font) private var fontRaw = ReaderFont.system.rawValue
    @AppStorage(SettingsKey.textSize) private var textSize = TextSizeSetting.defaultValue
    @AppStorage(SettingsKey.anchorColor) private var anchorColorRaw = AnchorColor.red.rawValue

    /// One motion curve for every state change, so all pieces move together.
    private let stateAnimation = Animation.smooth(duration: 0.45)

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            readingSurface
        }
        .overlay(alignment: .top) {
            if !viewModel.isPlaying {
                topBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            bottomArea
        }
        .statusBarHidden(viewModel.isPlaying)
        .persistentSystemOverlays(viewModel.isPlaying ? .hidden : .automatic)
        .animation(stateAnimation, value: viewModel.state)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.rewindCount)
        .interactiveDismissDisabled(viewModel.isPlaying)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.pause() }
        }
        .onDisappear { viewModel.pause() }
    }

    // MARK: - Reading surface (tap to play/pause, swipe right to rewind)

    /// The word sits at a fixed height (one third down) and never moves,
    /// whether the controls are showing or not.
    private var readingSurface: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            RSVPWordView(
                parts: viewModel.currentParts,
                fontScale: (viewModel.mode == .chunk ? 0.8 : 1) * textSize,
                anchorColor: (AnchorColor(rawValue: anchorColorRaw) ?? .red).color,
                fontDesign: ReaderFont(rawValue: fontRaw) ?? .system
            )
            .frame(height: 140)
            // Words must swap instantly, never cross-fade.
            .transaction { $0.animation = nil }

            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: 44)
                .opacity(viewModel.isPlaying ? 0 : 1)

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.togglePlayback() }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded(handleSwipe)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.title))
        .accessibilityValue(Text(hint))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { viewModel.togglePlayback() }
        .accessibilityAction(named: Text("Go back one sentence")) { viewModel.rewindSentence() }
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let dx = value.translation.width
        let dy = value.translation.height
        if dx > 60, abs(dx) > abs(dy) * 1.5 {
            viewModel.rewindSentence()
        }
    }

    private var hint: LocalizedStringKey {
        switch viewModel.state {
        case .ready: "Tap to start"
        case .playing: ""
        case .paused: "Tap to resume · Swipe right to go back"
        case .finished: "Tap to read again"
        }
    }

    // MARK: - Top bar (close + title, hidden while playing)

    private var topBar: some View {
        ZStack {
            Text(viewModel.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 64)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Bottom area (controls when paused, progress always)

    private var bottomArea: some View {
        VStack(spacing: 12) {
            if viewModel.state == .finished {
                finishedPanel()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if !viewModel.isPlaying {
                ReaderControlsPanel(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                HStack {
                    Text("\(timeRemainingText) left")
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))

                    Spacer()

                    if viewModel.canRestart {
                        Button {
                            viewModel.restart()
                        } label: {
                            Label("Start over", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .transition(.opacity)
            }

            // While playing, the bar glides to the end of the current word over exactly
            // that word's duration, so it moves continuously instead of in steps.
            ReadingProgressBar(value: viewModel.displayProgress)
                .padding(.horizontal, 8)
                .animation(progressAnimation, value: viewModel.displayProgress)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var progressAnimation: Animation {
        viewModel.isPlaying
            ? .linear(duration: viewModel.currentFrameSeconds)
            : stateAnimation
    }

    private var timeRemainingText: String {
        Duration.seconds(viewModel.secondsRemaining)
            .formatted(.time(pattern: .minuteSecond))
    }
}

#Preview {
    ReaderView(viewModel: ReaderViewModel(title: SampleText.title, text: SampleText.body)) {
        Text("Finished")
    }
}
