// Stillread/Services/ProgressCalculator.swift

import Foundation

struct DailyValue: Identifiable, Equatable, Sendable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct WeekDay: Identifiable, Equatable, Sendable {
    let date: Date
    let didRead: Bool
    var id: Date { date }
}

struct ModeBest: Identifiable, Equatable, Sendable {
    let mode: ReadingMode
    /// Highest speed at which a text was read to the end.
    let fastestFinish: Int?
    /// Highest wpm × accuracy.
    let bestEffective: Int?
    var id: ReadingMode { mode }
}

/// Everything the Progress screen shows, computed from the saved sessions (spec §7).
struct ProgressSummary {
    static let chartDays = 30

    let currentStreak: Int
    let bestStreak: Int
    /// The last 7 days, oldest first, with whether the user read that day.
    let week: [WeekDay]
    let textsFinished: Int
    let minutesRead: Int
    let wordsRead: Int
    let dailySpeed: [DailyValue]
    let dailyEffective: [DailyValue]
    let dailyAccuracy: [DailyValue]
    let bests: [ModeBest]

    init(sessions: [ReadingSession], now: Date = .now, calendar: Calendar = .current) {
        let streak = ProgressCalculator.streak(for: sessions.map(\.date), now: now, calendar: calendar)
        currentStreak = streak.current
        bestStreak = streak.best
        week = ProgressCalculator.week(for: sessions.map(\.date), now: now, calendar: calendar)

        textsFinished = sessions.filter(\.completed).count
        minutesRead = Int((sessions.reduce(0) { $0 + $1.durationSeconds } / 60).rounded())
        wordsRead = sessions.reduce(0) { $0 + $1.wordsRead }

        let recent = ProgressCalculator.sessions(sessions, inLast: Self.chartDays, now: now, calendar: calendar)
        dailySpeed = ProgressCalculator.dailyAverage(recent, calendar: calendar) { Double($0.wordsPerMinute) }
        dailyEffective = ProgressCalculator.dailyAverage(recent, calendar: calendar) { $0.effectiveWordsPerMinute.map(Double.init) }
        dailyAccuracy = ProgressCalculator.dailyAverage(recent, calendar: calendar) { $0.accuracy.map { $0 * 100 } }

        bests = ReadingMode.allCases.map { mode in
            let inMode = sessions.filter { $0.modeRaw == mode.rawValue }
            return ModeBest(
                mode: mode,
                fastestFinish: inMode.filter(\.completed).map(\.wordsPerMinute).max(),
                bestEffective: inMode.compactMap(\.effectiveWordsPerMinute).max()
            )
        }
    }
}

enum ProgressCalculator {
    /// Current streak counts back from today, or from yesterday if today has no reading yet.
    static func streak(for dates: [Date], now: Date = .now, calendar: Calendar = .current) -> (current: Int, best: Int) {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return (0, 0) }

        var current = 0
        var day = calendar.startOfDay(for: now)
        if !days.contains(day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }
        while days.contains(day) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        var best = 0
        var run = 0
        var previousDay: Date?
        for day in days.sorted() {
            if let previousDay,
               let expected = calendar.date(byAdding: .day, value: 1, to: previousDay),
               calendar.isDate(day, inSameDayAs: expected) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previousDay = day
        }

        return (current, max(best, current))
    }

    static func week(for dates: [Date], now: Date = .now, calendar: Calendar = .current) -> [WeekDay] {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return WeekDay(date: day, didRead: days.contains(day))
        }
    }

    static func sessions(_ sessions: [ReadingSession], inLast days: Int, now: Date, calendar: Calendar) -> [ReadingSession] {
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) else {
            return sessions
        }
        return sessions.filter { $0.date >= start }
    }

    /// Average of `value` per day, skipping sessions where it is nil. Oldest first.
    static func dailyAverage(
        _ sessions: [ReadingSession],
        calendar: Calendar,
        value: (ReadingSession) -> Double?
    ) -> [DailyValue] {
        var sums: [Date: (total: Double, count: Int)] = [:]
        for session in sessions {
            guard let v = value(session) else { continue }
            let day = calendar.startOfDay(for: session.date)
            let current = sums[day] ?? (0, 0)
            sums[day] = (current.total + v, current.count + 1)
        }
        return sums
            .map { DailyValue(date: $0.key, value: $0.value.total / Double($0.value.count)) }
            .sorted { $0.date < $1.date }
    }
}
