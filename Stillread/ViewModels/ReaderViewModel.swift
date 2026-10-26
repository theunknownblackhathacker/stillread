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
    static let speedPresets = [250, 350, 500, 700, 1000]
    static let defaultWordsPerMinute = 350

    let words: [Word]
    private(set) var plan: ReadingPlan
    private(set) var currentFrameIndex = 0
    private(set) var state: PlaybackState = .ready
    private(set) var wordsPerMinute: Int
    private(set) var mode: ReadingMode
    /// Bumped on every rewind; drives a light haptic in the view.
    private(set) var rewindCount = 0

    @ObservationIgnored private var playbackTask: Task<Void, Never>?

    private enum Keys {
        static let wordsPerMinute = "reader.wordsPerMinute"
        static let mode = "reader.mode"
    }

    init(text: String) {
        let defaults = UserDefaults.standard
        let words = Tokenizer.words(from: text)
        let savedSpeed = defaults.integer(forKey: Keys.wordsPerMinute)
        let speed = savedSpeed == 0 ? Self.defaultWordsPerMinute : savedSpeed.clamped(to: Self.wpmRange)
        let mode = defaults.string(forKey: Keys.mode).flatMap(ReadingMode.init(rawValue:)) ?? .standard

        self.words = words
        self.wordsPerMinute = speed
        self.mode = mode
        self.plan = ReadingPlan(words: words, mode: mode, wordsPerMinute: speed)
    }

    // MARK: - Derived state

    var currentFrame: ReadingFrame? {
        plan.frames.indices.contains(currentFrameIndex) ? plan.frames[currentFrameIndex] : nil
    }

    var currentParts: ORPParts {
        guard let frame = currentFrame else { return .empty }
        return frame.wordRange.count > 1
            ? OptimalRecognitionPoint.splitPhrase(frame.text)
            : OptimalRecognitionPoint.split(frame.text)
    }

    var isPlaying: Bool { state == .playing }

    var canRestart: Bool { currentFrameIndex > 0 || state == .finished }

    var progress: Double {
        if state == .finished { return 1 }
        guard let frame = currentFrame, words.count > 1 else { return 0 }
        return Double(frame.wordRange.lowerBound) / Double(words.count - 1)
    }

    var secondsRemaining: Int {
        guard state != .finished else { return 0 }
        return Int((plan.remainingMilliseconds(fromFrame: currentFrameIndex) / 1000).rounded(.up))
    }

    var rampStartWordsPerMinute: Int {
        ReadingPlan.rampStartSpeed(forTarget: wordsPerMinute)
    }

    // MARK: - Settings

    func setWordsPerMinute(_ value: Int) {
        let clamped = value.clamped(to: Self.wpmRange)
        guard clamped != wordsPerMinute else { return }
        wordsPerMinute = clamped
        UserDefaults.standard.set(clamped, forKey: Keys.wordsPerMinute)
        rebuildPlan()
    }

    func setMode(_ newMode: ReadingMode) {
        guard newMode != mode else { return }
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: Keys.mode)
        rebuildPlan()
    }

    // MARK: - Playback controls

    func togglePlayback() {
        switch state {
        case .playing:
            pause()
        case .ready, .paused:
            play()
        case .finished:
            currentFrameIndex = 0
            play()
        }
    }

    func play() {
        guard !plan.frames.isEmpty, state != .playing else { return }
        state = .playing
        cancelPlaybackTask()
        playbackTask = Task { [weak self] in
            await self?.runPlaybackLoop()
        }
    }

    func pause() {
        guard state == .playing else { return }
        cancelPlaybackTask()
        state = .paused
    }

    func restart() {
        cancelPlaybackTask()
        currentFrameIndex = 0
        state = .ready
    }

    /// Back to the start of the current sentence. If we are already at
    /// (or one word into) its start, go to the previous sentence instead.
    func rewindSentence() {
        guard let frame = currentFrame else { return }
        let word = frame.wordRange.lowerBound
        var target = sentenceStart(atOrBefore: word)
        if word - target < 2, target > 0 {
            target = sentenceStart(atOrBefore: target - 1)
        }

        let wasPlaying = state == .playing
        cancelPlaybackTask()
        currentFrameIndex = plan.frameIndex(containingWord: target)
        rewindCount += 1

        if wasPlaying {
            state = .paused
            play()
        } else {
            state = currentFrameIndex == 0 ? .ready : .paused
        }
    }

    // MARK: - Private

    private func rebuildPlan() {
        let word = currentFrame?.wordRange.lowerBound ?? 0
        plan = ReadingPlan(words: words, mode: mode, wordsPerMinute: wordsPerMinute)
        currentFrameIndex = plan.frameIndex(containingWord: word)
    }

    private func sentenceStart(atOrBefore index: Int) -> Int {
        var start = min(index, words.count - 1)
        while start > 0, !(words[start - 1].endsSentence || words[start - 1].endsParagraph) {
            start -= 1
        }
        return max(start, 0)
    }

    private func cancelPlaybackTask() {
        playbackTask?.cancel()
        playbackTask = nil
    }

    /// Deadline-based loop: each wake-up is scheduled from the previous deadline,
    /// not from "now", so small scheduling delays never accumulate into drift.
    private func runPlaybackLoop() async {
        let clock = ContinuousClock()
        var deadline = clock.now

        while !Task.isCancelled {
            guard let frame = currentFrame else { return }
            let interval = Duration.milliseconds(frame.durationMilliseconds)

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

            if currentFrameIndex < plan.frames.count - 1 {
                currentFrameIndex += 1
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
