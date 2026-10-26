// Stillread/ViewModels/ReaderViewModel.swift

import Foundation
import Observation

@MainActor
@Observable
final class ReaderViewModel {
    enum PlaybackState: Equatable {
        case ready
        case playing
        case paused
        case finished
    }

    static let wpmRange = 100...1000

    private(set) var words: [Word]
    private(set) var currentIndex = 0
    private(set) var state: PlaybackState = .ready

    private(set) var wordsPerMinute: Int = 350

    @ObservationIgnored private var playbackTask: Task<Void, Never>?

    init(text: String) {
        words = Tokenizer.words(from: text)
    }

    // MARK: - Derived state

    var currentWord: Word? {
        words.indices.contains(currentIndex) ? words[currentIndex] : nil
    }

    var isPlaying: Bool { state == .playing }

    var progress: Double {
        guard words.count > 1 else { return state == .finished ? 1 : 0 }
        return Double(currentIndex) / Double(words.count - 1)
    }

    // MARK: - Controls

    func togglePlayback() {
        switch state {
        case .playing:
            pause()
        case .ready, .paused:
            play()
        case .finished:
            currentIndex = 0
            play()
        }
    }

    func setWordsPerMinute(_ value: Int) {
        wordsPerMinute = value.clamped(to: Self.wpmRange)
    }

    func play() {
        guard !words.isEmpty, state != .playing else { return }
        state = .playing
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            await self?.runPlaybackLoop()
        }
    }

    func pause() {
        guard state == .playing else { return }
        playbackTask?.cancel()
        playbackTask = nil
        state = .paused
    }

    // MARK: - Timing

    /// Base interval per word: 60000 / wpm ms (spec §1). Multipliers come in Milestone 2.
    private var baseInterval: Duration {
        .milliseconds(60_000.0 / Double(wordsPerMinute))
    }

    /// Deadline-based loop: each wake-up is scheduled from the previous deadline,
    /// not from "now", so small scheduling delays never accumulate into drift.
    private func runPlaybackLoop() async {
        let clock = ContinuousClock()
        var deadline = clock.now

        while !Task.isCancelled {
            let interval = baseInterval

            // If we fell far behind (e.g. a long hitch), resync instead of racing ahead.
            if deadline.duration(to: clock.now) > interval {
                deadline = clock.now
            }
            deadline = deadline.advanced(by: interval)

            do {
                try await clock.sleep(until: deadline, tolerance: .milliseconds(2))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            if currentIndex < words.count - 1 {
                currentIndex += 1
            } else {
                state = .finished
                playbackTask = nil
                return
            }
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
