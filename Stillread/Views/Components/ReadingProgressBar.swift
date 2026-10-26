// Stillread/Views/Components/ReadingProgressBar.swift

import SwiftUI

/// Thin progress line. The fill is a scale transform, so animating it is cheap
/// and stays smooth at 120 Hz.
struct ReadingProgressBar: View {
    let value: Double
    var height: CGFloat = 3

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(.quaternary)

            Rectangle()
                .fill(.secondary)
                .scaleEffect(x: min(max(value, 0), 1), y: 1, anchor: .leading)
        }
        .frame(height: height)
        .clipShape(Capsule())
        .accessibilityElement()
        .accessibilityLabel(Text("Progress"))
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}
