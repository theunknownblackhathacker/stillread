// Stillread/Views/ReaderScreen.swift

import SwiftUI
import SwiftData

/// Connects a library text to the reader and saves the reading position
/// whenever playback stops or the reader closes.
struct ReaderScreen: View {
    let text: ReadingText
    let viewModel: ReaderViewModel

    var body: some View {
        ReaderView(viewModel: viewModel)
            .onChange(of: viewModel.state) {
                savePosition()
            }
            .onDisappear {
                viewModel.pause()
                savePosition()
            }
    }

    private func savePosition() {
        let index = viewModel.savedWordIndex
        if text.lastWordIndex != index {
            text.lastWordIndex = index
        }
    }
}
