// Stillread/Services/ReadingPlan.swift

import Foundation

/// What is on screen at one moment: one word, or a 2–3 word chunk.
struct ReadingFrame: Equatable, Sendable {
    let wordRange: Range<Int>
    let text: String
    let durationMilliseconds: Double
}

/// Precomputed frames and timings for one text at one speed and mode.
/// Rebuilt whenever speed or mode changes (cheap: one pass over the words).
struct ReadingPlan: Sendable {
    static let maxChunkWords = 3
    static let maxChunkCharacters = 16
    /// Ramp mode reaches the target speed after this share of the text, then holds it.
    static let rampPortion = 0.6

    let mode: ReadingMode
    let targetWordsPerMinute: Int
    let frames: [ReadingFrame]

    /// remaining[i] = total duration of frames i..<end. Has frames.count + 1 entries.
    private let remaining: [Double]

    init(words: [Word], mode: ReadingMode, wordsPerMinute: Int) {
        self.mode = mode
        self.targetWordsPerMinute = wordsPerMinute

        let ranges: [Range<Int>] = mode == .chunk
            ? Self.chunkRanges(for: words)
            : words.indices.map { $0..<($0 + 1) }

        var frames: [ReadingFrame] = []
        frames.reserveCapacity(ranges.count)

        for range in ranges {
            let speed = Self.speed(atWord: range.lowerBound, totalWords: words.count, mode: mode, target: wordsPerMinute)
            let base = 60_000 / speed
            let duration = range.reduce(0.0) { $0 + base * Self.multiplier(for: words[$1]) }
            let text = words[range].map(\.text).joined(separator: " ")
            frames.append(ReadingFrame(wordRange: range, text: text, durationMilliseconds: duration))
        }

        var remaining = [Double](repeating: 0, count: frames.count + 1)
        for index in stride(from: frames.count - 1, through: 0, by: -1) {
            remaining[index] = remaining[index + 1] + frames[index].durationMilliseconds
        }

        self.frames = frames
        self.remaining = remaining
    }

    // MARK: - Queries

    func remainingMilliseconds(fromFrame index: Int) -> Double {
        remaining[min(max(index, 0), frames.count)]
    }

    /// Share of total reading time that has passed when frame `index` starts (0...1).
    func elapsedFraction(beforeFrame index: Int) -> Double {
        let total = remaining[0]
        guard total > 0 else { return 0 }
        return 1 - remainingMilliseconds(fromFrame: index) / total
    }

    /// Index of the frame that shows the given word.
    func frameIndex(containingWord word: Int) -> Int {
        guard !frames.isEmpty else { return 0 }
        var low = 0
        var high = frames.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if frames[mid].wordRange.lowerBound <= word {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    // MARK: - Timing rules (spec §1, §2)

    /// Punctuation pause (largest applies) × long-word factor.
    static func multiplier(for word: Word) -> Double {
        let pause: Double =
            word.endsParagraph ? 2.5 :
            word.endsSentence ? 2.0 :
            word.endsClause ? 1.5 : 1.0
        let length: Double = word.letterCount > 8 ? 1.3 : 1.0
        return pause * length
    }

    /// Ramp starts at 60% of the target, never above 300 or below 100 wpm.
    static func rampStartSpeed(forTarget target: Int) -> Int {
        min(300, max(100, Int((Double(target) * 0.6).rounded())))
    }

    static func speed(atWord index: Int, totalWords: Int, mode: ReadingMode, target: Int) -> Double {
        guard mode == .ramp, totalWords > 1 else { return Double(target) }
        let start = Double(rampStartSpeed(forTarget: target))
        let span = max(Double(totalWords) * rampPortion, 1)
        let t = min(Double(index) / span, 1)
        return start + (Double(target) - start) * t
    }

    /// Groups words into chunks of up to 3 words / 16 characters.
    /// A chunk always ends at punctuation, so chunks never cross a clause or sentence.
    static func chunkRanges(for words: [Word]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start = 0
        var characters = 0

        for index in words.indices {
            let word = words[index]
            let count = index - start

            if count > 0, count == maxChunkWords || characters + 1 + word.text.count > maxChunkCharacters {
                ranges.append(start..<index)
                start = index
                characters = 0
            }

            characters += (index == start ? 0 : 1) + word.text.count

            if word.endsClause || word.endsSentence || word.endsParagraph {
                ranges.append(start..<(index + 1))
                start = index + 1
                characters = 0
            }
        }

        if start < words.count {
            ranges.append(start..<words.count)
        }
        return ranges
    }
}
