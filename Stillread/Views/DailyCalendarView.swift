// Stillread/Views/DailyCalendarView.swift

import SwiftUI

/// Calendar of past daily texts (spec §5). Days with a text get a dot; finished ones are filled.
struct DailyCalendarView: View {
    let texts: [ReadingText]
    /// Called with the chosen text; the caller closes this sheet and opens the reader.
    let onOpen: (ReadingText) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var direction: Edge = .trailing

    private let calendar = Calendar.current
    private let motion = Animation.smooth(duration: 0.4)

    var body: some View {
        let textsByDay = Dictionary(grouping: texts) { text in
            text.dailyKey.flatMap { DailyText.date(fromKey: $0) } ?? calendar.startOfDay(for: text.createdAt)
        }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    monthHeader

                    monthGrid(textsByDay: textsByDay)
                        .id(month)
                        .transition(.push(from: direction))

                    dayDetail(textsByDay[selectedDay] ?? [])
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("Daily texts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Month

    private var monthHeader: some View {
        HStack {
            Text(month, format: .dateTime.month(.wide).year())
                .font(.title2.weight(.semibold))
                .contentTransition(.opacity)

            Spacer()

            CircleIconButton(systemImage: "chevron.left", accessibilityLabel: "Previous month", size: 40) {
                changeMonth(by: -1)
            }
            CircleIconButton(systemImage: "chevron.right", accessibilityLabel: "Next month", size: 40) {
                changeMonth(by: 1)
            }
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.3 : 1)
        }
        .padding(.top, 8)
    }

    private func monthGrid(textsByDay: [Date: [ReadingText]]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        let today = calendar.startOfDay(for: .now)

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(weekdaySymbols.indices, id: \.self) { index in
                Text(weekdaySymbols[index])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            ForEach(Array(daySlots.enumerated()), id: \.offset) { _, day in
                if let day {
                    let dayTexts = textsByDay[day] ?? []
                    DayCell(
                        date: day,
                        isToday: day == today,
                        isSelected: day == selectedDay,
                        isFuture: day > today,
                        hasText: !dayTexts.isEmpty,
                        isFinished: dayTexts.contains(where: \.isFinished)
                    ) {
                        withAnimation(motion) { selectedDay = day }
                    }
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func dayDetail(_ dayTexts: [ReadingText]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDay, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.headline)
                .foregroundStyle(.secondary)

            if dayTexts.isEmpty {
                Text("No daily text on this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                ForEach(dayTexts) { text in
                    Button {
                        onOpen(text)
                    } label: {
                        DailyTextRow(text: text)
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
        }
        .id(selectedDay)
        .transition(.opacity)
        .animation(motion, value: selectedDay)
    }

    // MARK: - Calendar maths

    /// Weekday initials starting from the user's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Leading blanks, then each day of the month.
    private var daySlots: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let days: [Date?] = range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: month)
        }
        return Array(repeating: nil, count: leading) + days
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private func changeMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: month) else { return }
        direction = value > 0 ? .trailing : .leading
        withAnimation(motion) { month = next }
    }
}

private struct DayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let isFuture: Bool
    let hasText: Bool
    let isFinished: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(date, format: .dateTime.day())
                    .font(.body.weight(isToday ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color(.systemBackground) : (isFuture ? Color.secondary : Color.primary))
                    .frame(width: 36, height: 36)
                    .background {
                        if isSelected {
                            Circle().fill(Color.primary)
                        } else if isToday {
                            Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 1.5)
                        }
                    }

                Circle()
                    .fill(isFinished ? Color.orange : Color.orange.opacity(0.45))
                    .frame(width: 6, height: 6)
                    .opacity(hasText ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(Text(date, format: .dateTime.day().month(.wide)))
        .accessibilityValue(hasText ? (isFinished ? Text("Read") : Text("Daily text")) : Text(verbatim: ""))
    }
}

private struct DailyTextRow: View {
    let text: ReadingText

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(text.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(meta)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if text.isInProgress {
                    ReadingProgressBar(value: text.progress)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: text.isFinished ? "checkmark.circle.fill" : "play.circle.fill")
                .font(.title)
                .foregroundStyle(text.isFinished ? Color.orange : Color.primary)
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var meta: String {
        let language = text.language.flatMap { ReadingLanguage(rawValue: $0)?.nativeName } ?? ""
        let level = text.level ?? ""
        return [language, level, String(localized: "\(text.wordCount) words")]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
