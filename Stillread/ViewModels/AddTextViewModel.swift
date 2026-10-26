// Stillread/ViewModels/AddTextViewModel.swift

import Foundation
import NaturalLanguage
import Observation

/// Backs the "New text" sheet: paste, import a file, scan pages or receive a shared page.
/// Every import fills the editor first, so the text can be checked before saving.
@MainActor
@Observable
final class AddTextViewModel {
    static let autoTitleWordLimit = 6

    var title = ""
    var body = ""
    private(set) var source: TextSource = .paste
    /// Non-nil while an import is running; shown over the editor.
    private(set) var importStatus: LocalizedStringResource?
    private(set) var importError: LocalizedStringResource?

    @ObservationIgnored private var importTask: Task<Void, Never>?

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var wordCount: Int {
        trimmedBody.split(whereSeparator: \.isWhitespace).count
    }

    var isImporting: Bool { importStatus != nil }

    var canSave: Bool { wordCount > 0 && !isImporting }

    // MARK: - Sources

    /// Pasting a single link fetches the article; otherwise text is added to the editor.
    func paste(_ strings: [String]) {
        let pasted = strings
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pasted.isEmpty else { return }

        if let url = IncomingImport.singleWebURL(in: pasted) {
            importWebPage(url)
            return
        }
        importError = nil
        body = trimmedBody.isEmpty ? pasted : trimmedBody + "\n\n" + pasted
    }

    /// Text that arrived from the Share Extension or the clipboard fallback.
    func receiveShared(_ string: String, title: String? = nil) {
        if let url = IncomingImport.singleWebURL(in: string) {
            importWebPage(url)
        } else {
            fill(with: ImportedText(title: title, text: TextCleaner.reflow(string), source: .share))
        }
    }

    func importFile(at url: URL) {
        runImport(status: "Reading file…") {
            try await DocumentImporter.load(url)
        }
    }

    /// - Parameter pages: JPEG data of each scanned page.
    func importScan(_ pages: [Data]) {
        guard !pages.isEmpty else { return }
        runImport(status: "Recognizing text…") {
            try await TextRecognizer.recognize(pages: pages)
        }
    }

    func importWebPage(_ url: URL) {
        runImport(status: "Fetching article…") {
            try await WebArticleExtractor.fetch(url)
        }
    }

    func cancelImport() {
        importTask?.cancel()
        importTask = nil
        importStatus = nil
    }

    private func runImport(
        status: LocalizedStringResource,
        operation: @escaping @Sendable () async throws -> ImportedText
    ) {
        importTask?.cancel()
        importError = nil
        importStatus = status

        importTask = Task { [weak self] in
            do {
                let imported = try await operation()
                try Task.checkCancellation()
                self?.fill(with: imported)
            } catch is CancellationError {
                // Replaced by a newer import or the sheet closed.
            } catch {
                self?.importError = ImportError.message(for: error)
            }
            if !Task.isCancelled {
                self?.importStatus = nil
            }
        }
    }

    private func fill(with imported: ImportedText) {
        if let importedTitle = imported.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !importedTitle.isEmpty {
            title = importedTitle
        }
        body = imported.text
        source = imported.source
        importError = nil
    }

    // MARK: - Saving

    func makeText() -> ReadingText? {
        let cleaned = trimmedBody
        guard !cleaned.isEmpty else { return nil }
        let language = NLLanguageRecognizer.dominantLanguage(for: String(cleaned.prefix(2000)))
        return ReadingText(
            title: resolvedTitle(for: cleaned),
            body: cleaned,
            source: source,
            language: language?.rawValue
        )
    }

    /// The typed title, or the first few words of the text.
    private func resolvedTitle(for text: String) -> String {
        let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }

        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let allWords = firstLine.split(whereSeparator: \.isWhitespace)
        let words = allWords.prefix(Self.autoTitleWordLimit)
        var result = words.joined(separator: " ")

        if allWords.count > Self.autoTitleWordLimit {
            while let last = result.last, last.isPunctuation {
                result.removeLast()
            }
            result += "…"
        }
        return result
    }
}
