// Stillread/Models/TextSource.swift

import Foundation

/// Where a text came from (spec data model), plus `sample` for the built-in welcome text.
enum TextSource: String, Codable, CaseIterable, Sendable {
    case sample
    case ai
    case paste
    case pdf
    case scan
    case share

    var label: LocalizedStringResource {
        switch self {
        case .sample: "Sample"
        case .ai: "AI"
        case .paste: "Pasted"
        case .pdf: "PDF"
        case .scan: "Scan"
        case .share: "Shared"
        }
    }

    var symbolName: String {
        switch self {
        case .sample: "book.closed"
        case .ai: "sparkles"
        case .paste: "doc.on.clipboard"
        case .pdf: "doc.richtext"
        case .scan: "doc.viewfinder"
        case .share: "square.and.arrow.down"
        }
    }
}
