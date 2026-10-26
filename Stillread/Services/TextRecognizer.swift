// Stillread/Services/TextRecognizer.swift

import Foundation
import Vision

/// On-device text recognition for scanned pages (spec §4b).
enum TextRecognizer {
    /// - Parameter pages: JPEG data for each scanned page, in order.
    @concurrent
    static func recognize(pages: [Data]) async throws -> ImportedText {
        var pageTexts: [String] = []

        for data in pages {
            try Task.checkCancellation()
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(data: data, options: [:])
            try handler.perform([request])
            pageTexts.append(layout(request.results ?? []))
        }

        let text = TextCleaner.reflow(pageTexts.joined(separator: "\n"))
        guard !text.isEmpty else { throw ImportError.noText }
        return ImportedText(title: nil, text: text, source: .scan)
    }

    /// Lines in reading order; a vertical gap bigger than about one line height
    /// becomes a blank line, i.e. a paragraph break.
    private static func layout(_ observations: [VNRecognizedTextObservation]) -> String {
        let heights = observations.map(\.boundingBox.height).sorted()
        let typicalHeight = heights.isEmpty ? 0 : heights[heights.count / 2]

        var lines: [String] = []
        var previous: CGRect?

        for observation in observations {
            guard let text = observation.topCandidates(1).first?.string, !text.isEmpty else { continue }
            let box = observation.boundingBox
            // Vision's coordinates start at the bottom-left, so "below" means a smaller y.
            if let previous, previous.minY - box.maxY > typicalHeight * 0.9 {
                lines.append("")
            }
            lines.append(text)
            previous = box
        }

        return lines.joined(separator: "\n")
    }
}
