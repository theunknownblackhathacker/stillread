// Stillread/Services/DailyText.swift

import Foundation

/// Keys and dates for daily texts (spec §5): one text per day per language and level.
enum DailyText {
    static func key(for date: Date, language: ReadingLanguage, level: ReadingLevel, calendar: Calendar = .current) -> String {
        "\(dayString(for: date, calendar: calendar))|\(language.rawValue)|\(level.rawValue)"
    }

    static func dayString(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The day part of a daily key, as the start of that day.
    static func date(fromKey key: String, calendar: Calendar = .current) -> Date? {
        let day = key.split(separator: "|").first.map(String.init) ?? ""
        let numbers = day.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: numbers[0], month: numbers[1], day: numbers[2]))
    }
}
