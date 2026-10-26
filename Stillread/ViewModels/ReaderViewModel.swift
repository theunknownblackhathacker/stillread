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
    /// Short pause after tapping play, so the controls finish gliding away before words move.
    static let leadInSeconds = 0.35

    let title: String
    let words: [Word]
    let excerpt: String
    private(set) var plan: ReadingPlan
    private(set) var currentFrameIndex = 0
    private(set) var state: PlaybackState = .ready
    private(set) var wordsPerMinute: Int
    private(set) var mode: ReadingMode
    /// Bumped on every rewind; drives a light haptic in the view.
    private(set) var rewindCount = 0

    @ObservationIgnored private let displayLink: DisplayLinkDriver
    /// Media time (CACurrentMediaTime base) at which the next frame should appear.
    @ObservationIgnored private var nextSwapTime: Double?

    private enum Keys {
        static let wordsPerMinute = "reader.wordsPerMinute"
        static let mode = "reader.mode"
    }

    init(title: String, text: String) {
        let defaults = UserDefaults.standard
        let words = Tokenizer.words(from: text)
        let savedSpeed = defaults.integer(forKey: Keys.wordsPerMinute)
        let speed = savedSpeed == 0 ? Self.defaultWordsPerMinute : savedSpeed.clamped(to: Self.wpmRange)
        let mode = defaults.string(forKey: Keys.mode).flatMap(ReadingMode.init(rawValue:)) ?? .standard
        let excerptWords = words.prefix(28).map(\.text).joined(separator: " ")

        self.title = title
        self.words = words
        self.excerpt = words.count > 28 ? excerptWords + "…" : excerptWords
        self.wordsPerMinute = speed
        self.mode = mode
        self.plan = ReadingPlan(words: words, mode: mode, wordsPerMinute: speed)
        self.displayLink = DisplayLinkDriver()
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

    var hasStarted: Bool { currentFrameIndex > 0 || state != .ready }

    var canRestart: Bool { currentFrameIndex > 0 || state == .finished }

    /// Time-based progress. While a frame is showing, this is where the bar should be
    /// when that frame ends, so the view can glide to it over the frame's duration.
    var displayProgress: Double {
        switch state {
        case .ready: 0
        case .finished: 1
        case .playing, .paused: plan.elapsedFraction(beforeFrame: currentFrameIndex + 1)
        }
    }

    var currentFrameSeconds: Double {
        (currentFrame?.durationMilliseconds ?? 0) / 1000
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
        startTicking(leadIn: Self.leadInSeconds)
    }

    func pause() {
        guard state == .playing else { return }
        stopTicking()
        state = .paused
    }

    func restart() {
        stopTicking()
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

        currentFrameIndex = plan.frameIndex(containingWord: target)
        rewindCount += 1

        if state == .playing {
            startTicking(leadIn: 0)
        } else {
            state = currentFrameIndex == 0 ? .ready : .paused
        }
    }

    // MARK: - Display-synced playback

    private func startTicking(leadIn: Double) {
        nextSwapTime = nil
        displayLink.start { [weak self, weak displayLink] target, frameDuration in
            guard let self else {
                displayLink?.stop()
                return
            }
            self.handleRefresh(target: target, frameDuration: frameDuration, leadIn: leadIn)
        }
    }

    private func stopTicking() {
        displayLink.stop()
        nextSwapTime = nil
    }

    /// Runs once per screen refresh. Swaps to the next frame on the refresh closest to
    /// its deadline. Deadlines are chained from the ideal time, not the actual swap time,
    /// so rounding to refreshes never accumulates into drift.
    private func handleRefresh(target: Double, frameDuration: Double, leadIn: Double) {
        guard state == .playing, let frame = currentFrame else { return }

        guard let deadline = nextSwapTime else {
            nextSwapTime = target + leadIn + frame.durationMilliseconds / 1000
            return
        }

        guard target + frameDuration / 2 >= deadline else { return }

        guard currentFrameIndex < plan.frames.count - 1 else {
            stopTicking()
            state = .finished
            return
        }

        currentFrameIndex += 1
        let duration = plan.frames[currentFrameIndex].durationMilliseconds / 1000
        // After a long hitch (more than a whole frame late), resync instead of racing ahead.
        nextSwapTime = target - deadline > duration ? target + duration : deadline + duration
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
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
