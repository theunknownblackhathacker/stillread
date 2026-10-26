// Stillread/Views/ReaderView.swift

import SwiftUI

struct ReaderView: View {
    @State private var viewModel = ReaderViewModel(text: SampleText.body)
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            RSVPWordView(word: viewModel.currentWord?.text ?? "")
                .frame(height: 140)

            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(height: 44)
                .opacity(viewModel.isPlaying ? 0 : 1)

            Spacer()

            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
                .tint(.secondary)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture { viewModel.togglePlayback() }
        .statusBarHidden(viewModel.isPlaying)
        .persistentSystemOverlays(viewModel.isPlaying ? .hidden : .automatic)
        .animation(.easeInOut(duration: 0.25), value: viewModel.state)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.pause() }
        }
        .onDisappear { viewModel.pause() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(SampleText.title))
        .accessibilityValue(Text(hint))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { viewModel.togglePlayback() }
    }

    private var hint: LocalizedStringKey {
        switch viewModel.state {
        case .ready: "\(viewModel.wordsPerMinute) wpm · Tap to start"
        case .playing: ""
        case .paused: "Paused · Tap to resume"
        case .finished: "Tap to read again"
        }
    }
}

#Preview {
    ReaderView()
}
