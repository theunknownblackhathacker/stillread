// Stillread/Views/ReaderView.swift

import SwiftUI

struct ReaderView: View {
    @State private var viewModel = ReaderViewModel(text: SampleText.body)
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            readingSurface
        }
        .overlay(alignment: .bottom) {
            bottomArea
        }
        .statusBarHidden(viewModel.isPlaying)
        .persistentSystemOverlays(viewModel.isPlaying ? .hidden : .automatic)
        .animation(.easeInOut(duration: 0.25), value: viewModel.state)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.rewindCount)
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
                fontScale: viewModel.mode == .chunk ? 0.8 : 1
            )
            .frame(height: 140)

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
        .accessibilityLabel(Text(SampleText.title))
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

    // MARK: - Bottom area (controls when paused, progress always)

    private var bottomArea: some View {
        VStack(spacing: 12) {
            if !viewModel.isPlaying {
                ReaderControlsPanel(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                HStack {
                    Text("\(timeRemainingText) left")
                        .monospacedDigit()

                    Spacer()

                    if viewModel.canRestart {
                        Button {
                            viewModel.restart()
                        } label: {
                            Label("Start over", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .transition(.opacity)
            }

            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
                .tint(.secondary)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var timeRemainingText: String {
        Duration.seconds(viewModel.secondsRemaining)
            .formatted(.time(pattern: .minuteSecond))
    }
}

#Preview {
    ReaderView()
}
