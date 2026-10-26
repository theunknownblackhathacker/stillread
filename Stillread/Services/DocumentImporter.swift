// Stillread/Services/DocumentImporter.swift

import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Text brought in from outside the app, ready to review and save.
struct ImportedText: Sendable {
    var title: String?
    var text: String
    var source: TextSource
}

enum ImportError: Error {
    case unreadable
    case locked
    case noSelectableText
    case noText
    case noArticle
    case network

    static func message(for error: Error) -> LocalizedStringResource {
        if let error = error as? ImportError {
            switch error {
            case .unreadable: return "This file couldn't be opened."
            case .locked: return "This PDF is password-protected."
            case .noSelectableText: return "This PDF has no selectable text. Try Scan instead."
            case .noText: return "No text was found."
            case .noArticle: return "Couldn't find readable text on this page."
            case .network: return "Couldn't load this page. Check your connection and try again."
            }
        }
        if error is URLError {
            return "Couldn't load this page. Check your connection and try again."
        }
        return "Something went wrong while importing."
    }
}

/// PDF (PDFKit) and plain-text import (spec §4b).
enum DocumentImporter {
    @concurrent
    static func load(_ url: URL) async throws -> ImportedText {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
            // Files opened with "Open in Stillread" are copied to Inbox; tidy up.
            if url.path().contains("/Inbox/") { try? FileManager.default.removeItem(at: url) }
        }

        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .pdf) == true {
            return try loadPDF(url)
        }
        return try loadPlainText(url)
    }

    private static func loadPDF(_ url: URL) throws -> ImportedText {
        guard let document = PDFDocument(url: url) else { throw ImportError.unreadable }
        if document.isLocked { throw ImportError.locked }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            if let text = document.page(at: index)?.string {
                pages.append(text)
            }
        }

        let text = TextCleaner.reflow(pages.joined(separator: "\n"))
        guard text.split(whereSeparator: \.isWhitespace).count >= 5 else {
            throw ImportError.noSelectableText
        }

        let attributeTitle = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        return ImportedText(
            title: nonEmpty(attributeTitle) ?? fileTitle(url),
            text: text,
            source: .pdf
        )
    }

    private static func loadPlainText(_ url: URL) throws -> ImportedText {
        var encoding = String.Encoding.utf8
        let raw: String
        if let detected = try? String(contentsOf: url, usedEncoding: &encoding) {
            raw = detected
        } else if let latin = try? String(contentsOf: url, encoding: .isoLatin1) {
            raw = latin
        } else {
            throw ImportError.unreadable
        }

        let text = TextCleaner.reflow(raw)
        guard !text.isEmpty else { throw ImportError.noText }
        return ImportedText(title: fileTitle(url), text: text, source: .file)
    }

    private static func fileTitle(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
    }

    private static func nonEmpty(_ string: String?) -> String? {
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
