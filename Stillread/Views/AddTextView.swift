// Stillread/Views/AddTextView.swift

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Sheet for adding your own text: paste, import a PDF/.txt, or scan printed pages.
/// Shared pages from Safari land here too, already filled in.
struct AddTextView: View {
    let viewModel: AddTextViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedField: Field?
    @State private var isPickingFile = false
    @State private var isScanning = false

    private enum Field {
        case title
        case body
    }

    var body: some View {
        let model = viewModel
        @Bindable var viewModel = viewModel

        NavigationStack {
            VStack(spacing: 0) {
                sourceBar(model)

                TextField("Title (optional)", text: $viewModel.title)
                    .font(.title3.weight(.semibold))
                    .submitLabel(.next)
                    .focused($focusedField, equals: .title)
                    .onSubmit { focusedField = .body }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                Divider()
                    .padding(.horizontal, 20)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.body)
                        .font(.body)
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .focused($focusedField, equals: .body)
                        .padding(.horizontal, 15)
                        .padding(.top, 4)

                    if viewModel.body.isEmpty, !viewModel.isImporting {
                        Text("Paste or type your text here, or import a PDF, a .txt file or a scanned page.")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }

                    if let status = viewModel.importStatus {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(status)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                        .transition(.opacity)
                    }
                }

                if let error = viewModel.importError {
                    Label {
                        Text(error)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.35), value: viewModel.isImporting)
            .animation(.smooth(duration: 0.35), value: viewModel.body.isEmpty)
            .background(Color(.systemBackground))
            .navigationTitle("New text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        model.cancelImport()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!viewModel.canSave)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Label {
                        Text(viewModel.source.label)
                    } icon: {
                        Image(systemName: viewModel.source.symbolName)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(viewModel.wordCount) words")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.pdf, .plainText]) { result in
                if case .success(let url) = result {
                    model.importFile(at: url)
                }
            }
            .fullScreenCover(isPresented: $isScanning) {
                DocumentScannerView { images in
                    isScanning = false
                    let pages = images.compactMap { $0.jpegData(compressionQuality: 0.85) }
                    model.importScan(pages)
                } onCancel: {
                    isScanning = false
                }
                .ignoresSafeArea()
            }
        }
        .interactiveDismissDisabled(viewModel.isImporting)
    }

    private func sourceBar(_ model: AddTextViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PasteButton(payloadType: String.self) { strings in
                    Task { @MainActor in
                        model.paste(strings)
                    }
                }
                .buttonBorderShape(.capsule)
                .labelStyle(.titleAndIcon)

                SourceChip(title: "File", systemImage: "doc") {
                    isPickingFile = true
                }

                if DocumentScannerView.isSupported {
                    SourceChip(title: "Scan", systemImage: "doc.viewfinder") {
                        isScanning = true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private func save() {
        guard let text = viewModel.makeText() else { return }
        withAnimation(.smooth(duration: 0.45)) {
            modelContext.insert(text)
        }
        dismiss()
    }
}

private struct SourceChip: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressableCardStyle())
    }
}

#Preview {
    AddTextView(viewModel: AddTextViewModel())
        .modelContainer(for: ReadingText.self, inMemory: true)
}
