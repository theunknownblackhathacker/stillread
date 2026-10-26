// Stillread/Views/ProgressScreen.swift

import SwiftUI
import SwiftData
import Charts

/// Progress (spec §7): streak, totals, WPM history, quiz accuracy, personal bests per mode.
struct ProgressScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    @State private var hasAppeared = false

    var body: some View {
        let summary = ProgressSummary(sessions: sessions)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if sessions.isEmpty {
                        emptyState
                            .entrance(hasAppeared, delay: 0)
                    } else {
                        StreakCard(summary: summary)
                            .entrance(hasAppeared, delay: 0)

                        HStack(spacing: 12) {
                            StatTile(value: summary.textsFinished.formatted(), label: "Texts finished")
                            StatTile(value: summary.minutesRead.formatted(), label: "Minutes read")
                            StatTile(value: summary.wordsRead.formatted(.number.notation(.compactName)), label: "Words read")
                        }
                        .entrance(hasAppeared, delay: 0.06)

                        if !summary.dailySpeed.isEmpty {
                            SpeedChartCard(speed: summary.dailySpeed, effective: summary.dailyEffective)
                                .entrance(hasAppeared, delay: 0.12)
                        }

                        if !summary.dailyAccuracy.isEmpty {
                            AccuracyChartCard(values: summary.dailyAccuracy)
                                .entrance(hasAppeared, delay: 0.18)
                        }

                        BestsCard(bests: summary.bests)
                            .entrance(hasAppeared, delay: 0.24)

                        RecentSessionsCard(sessions: Array(sessions.prefix(8)))
                            .entrance(hasAppeared, delay: 0.3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { hasAppeared = true }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("No reading yet")
                .font(.title3.weight(.semibold))
            Text("Read a text for at least 20 seconds, or finish one, and your progress will show up here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Card container

private struct Card<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct CardHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Streak

private struct StreakCard: View {
    let summary: ProgressSummary

    var body: some View {
        Card {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(summary.currentStreak > 0 ? Color.orange : Color.secondary)
                Text(summary.currentStreak, format: .number)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("day streak")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Best")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(summary.bestStreak) days")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }

            HStack(spacing: 0) {
                ForEach(summary.week) { day in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(day.didRead ? Color.orange : Color.primary.opacity(0.08))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if day.didRead {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        Text(day.date, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide)))
                    .accessibilityValue(day.didRead ? Text("Read") : Text("No reading"))
                }
            }
        }
    }
}

// MARK: - Speed chart

private struct SpeedChartCard: View {
    let speed: [DailyValue]
    let effective: [DailyValue]

    @State private var selectedDay: Date?

    private let speedName = "Speed"
    private let effectiveName = "Effective"

    var body: some View {
        Card {
            CardHeader(title: "Reading speed", subtitle: "Words per minute, daily average · last 30 days")

            Chart {
                series(speed, name: speedName)
                series(effective, name: effectiveName)

                if let selectedDay {
                    RuleMark(x: .value("Day", selectedDay, unit: .day))
                        .foregroundStyle(Color.primary.opacity(0.25))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(
                            position: .top,
                            spacing: 6,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            ChartTooltip(date: selectedDay, rows: tooltipRows(for: selectedDay))
                        }
                }
            }
            .chartForegroundStyleScale(domain: seriesNames, range: seriesColors)
            .chartLegend(position: .top, alignment: .leading)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                    AxisValueLabel()
                }
            }
            .chartXSelection(value: $selectedDay)
            .frame(height: 210)
        }
    }

    private var seriesNames: [String] {
        effective.isEmpty ? [speedName] : [speedName, effectiveName]
    }

    private var seriesColors: [Color] {
        effective.isEmpty ? [ChartPalette.series1] : [ChartPalette.series1, ChartPalette.series2]
    }

    @ChartContentBuilder
    private func series(_ values: [DailyValue], name: String) -> some ChartContent {
        ForEach(values) { point in
            LineMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("WPM", point.value),
                series: .value("Series", name)
            )
            .foregroundStyle(by: .value("Series", name))
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("WPM", point.value)
            )
            .foregroundStyle(by: .value("Series", name))
            .symbolSize(50)
            .annotation(position: .top, spacing: 4) {
                // Direct label on the latest point only.
                if point.id == values.last?.id {
                    Text(Int(point.value.rounded()), format: .number)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func tooltipRows(for day: Date) -> [ChartTooltip.Row] {
        var rows: [ChartTooltip.Row] = []
        if let value = speed.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            rows.append(.init(color: ChartPalette.series1, label: speedName, value: "\(Int(value.value.rounded())) wpm"))
        }
        if let value = effective.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            rows.append(.init(color: ChartPalette.series2, label: effectiveName, value: "\(Int(value.value.rounded())) wpm"))
        }
        return rows
    }
}

// MARK: - Accuracy chart

private struct AccuracyChartCard: View {
    let values: [DailyValue]

    @State private var selectedDay: Date?

    var body: some View {
        Card {
            CardHeader(title: "Quiz accuracy", subtitle: "Correct answers, daily average · last 30 days")

            Chart {
                ForEach(values) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Accuracy", point.value)
                    )
                    .foregroundStyle(ChartPalette.series1)
                    .cornerRadius(4)
                    .opacity(isHighlighted(point.date) ? 1 : 0.35)
                }

                if let selectedDay,
                   let point = values.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }) {
                    RuleMark(x: .value("Day", point.date, unit: .day))
                        .foregroundStyle(Color.clear)
                        .annotation(
                            position: .top,
                            spacing: 0,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            ChartTooltip(
                                date: point.date,
                                rows: [.init(color: ChartPalette.series1, label: "Accuracy", value: "\(Int(point.value.rounded()))%")]
                            )
                        }
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0.0, 50.0, 100.0]) { value in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                    AxisValueLabel {
                        if let percent = value.as(Double.self) {
                            Text("\(Int(percent))%")
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedDay)
            .frame(height: 180)
        }
    }

    private func isHighlighted(_ date: Date) -> Bool {
        guard let selectedDay else { return true }
        return Calendar.current.isDate(date, inSameDayAs: selectedDay)
    }
}

// MARK: - Tooltip

private struct ChartTooltip: View {
    struct Row: Identifiable {
        let color: Color
        let label: String
        let value: String
        var id: String { label }
    }

    let date: Date
    let rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    Circle()
                        .fill(row.color)
                        .frame(width: 8, height: 8)
                    Text(verbatim: row.label)
                        .foregroundStyle(.secondary)
                    Text(verbatim: row.value)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
                .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}

// MARK: - Personal bests

private struct BestsCard: View {
    let bests: [ModeBest]

    var body: some View {
        Card {
            CardHeader(title: "Personal bests", subtitle: "Per reading mode")

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Mode")
                    Text("Fastest finish")
                        .gridColumnAlignment(.trailing)
                    Text("Best effective")
                        .gridColumnAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(bests) { best in
                    Divider()
                    GridRow {
                        Text(best.mode.title)
                            .font(.subheadline.weight(.medium))
                        Text(verbatim: wpmText(best.fastestFinish))
                            .font(.subheadline)
                            .monospacedDigit()
                        Text(verbatim: best.mode.showsQuiz ? wpmText(best.bestEffective) : "—")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(best.mode.showsQuiz ? HierarchicalShapeStyle.primary : HierarchicalShapeStyle.tertiary)
                    }
                }
            }
        }
    }

    private func wpmText(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value.formatted()) wpm"
    }
}

// MARK: - Recent sessions

private struct RecentSessionsCard: View {
    let sessions: [ReadingSession]

    var body: some View {
        Card {
            CardHeader(title: "Recent")

            VStack(spacing: 12) {
                ForEach(sessions) { session in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.textTitle)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text("\(Text(session.mode.title)) · \(session.date, format: .relative(presentation: .named))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(session.wordsPerMinute) wpm")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                            if session.hasQuiz {
                                Text("\(session.score)/\(session.totalQuestions) correct")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if !session.completed {
                                Text("Partial")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if session.id != sessions.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

#Preview {
    ProgressScreen()
        .modelContainer(for: [ReadingText.self, QuizQuestion.self, ReadingSession.self], inMemory: true)
}
