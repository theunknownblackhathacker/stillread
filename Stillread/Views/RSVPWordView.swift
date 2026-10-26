// Stillread/Views/RSVPWordView.swift

import SwiftUI
import UIKit

/// Shows one word (or chunk) with its anchor letter pinned to the horizontal centre.
/// Prefix and suffix get equal-width frames on each side of the anchor, so the anchor's
/// centre never moves. Long text shrinks uniformly so it never truncates.
struct RSVPWordView: View {
    let parts: ORPParts
    var fontScale: CGFloat = 1
    var anchorColor: Color = .red

    @ScaledMetric(relativeTo: .largeTitle) private var scaledFontSize: CGFloat = 46

    private let uiWeight: UIFont.Weight = .medium
    private let fontWeight: Font.Weight = .medium
    private let horizontalPadding: CGFloat = 20

    private var baseFontSize: CGFloat { scaledFontSize * fontScale }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fontSize = fittingFontSize(in: width)
            let anchorWidth = measure(parts.anchor, size: fontSize)
            let sideWidth = max((width - anchorWidth) / 2, 0)

            ZStack {
                ReadingGuides()

                HStack(spacing: 0) {
                    Text(parts.prefix)
                        .fixedSize()
                        .frame(width: sideWidth, alignment: .trailing)

                    Text(parts.anchor)
                        .foregroundStyle(anchorColor)
                        .fixedSize()
                        .frame(width: anchorWidth)

                    Text(parts.suffix)
                        .fixedSize()
                        .frame(width: sideWidth, alignment: .leading)
                }
                .font(.system(size: fontSize, weight: fontWeight))
                .foregroundStyle(.primary)
            }
            .frame(width: width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Measuring

    private func fittingFontSize(in width: CGFloat) -> CGFloat {
        let anchorHalf = measure(parts.anchor, size: baseFontSize) / 2
        let widestSide = max(
            measure(parts.prefix, size: baseFontSize),
            measure(parts.suffix, size: baseFontSize)
        ) + anchorHalf
        let available = width / 2 - horizontalPadding

        guard widestSide > available, widestSide > 0, available > 0 else { return baseFontSize }
        return max(baseFontSize * available / widestSide, 12)
    }

    private func measure(_ text: String, size: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let font = UIFont.systemFont(ofSize: size, weight: uiWeight)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

/// Two hairlines with a small notch above and below the anchor position.
private struct ReadingGuides: View {
    private let inset: CGFloat = 24
    private let notch: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let mid = width / 2

            Path { path in
                path.move(to: CGPoint(x: inset, y: 0.5))
                path.addLine(to: CGPoint(x: width - inset, y: 0.5))
                path.move(to: CGPoint(x: mid, y: 0.5))
                path.addLine(to: CGPoint(x: mid, y: notch))

                path.move(to: CGPoint(x: inset, y: height - 0.5))
                path.addLine(to: CGPoint(x: width - inset, y: height - 0.5))
                path.move(to: CGPoint(x: mid, y: height - 0.5))
                path.addLine(to: CGPoint(x: mid, y: height - notch))
            }
            .stroke(.tertiary, lineWidth: 1)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        RSVPWordView(parts: OptimalRecognitionPoint.split("reading")).frame(height: 140)
        RSVPWordView(parts: OptimalRecognitionPoint.split("“Hello,")).frame(height: 140)
        RSVPWordView(parts: OptimalRecognitionPoint.splitPhrase("the quiet line"), fontScale: 0.8).frame(height: 140)
    }
}
