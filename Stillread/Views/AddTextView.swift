// Stillread/Views/AddTextView.swift

import SwiftUI
import SwiftData

/// Sheet for pasting or typing your own text.
struct AddTextView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = AddTextViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case body
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        let model = self.viewModel

        NavigationStack {
            VStack(spacing: 0) {
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

                    if viewModel.body.isEmpty {
                        Text("Paste or type your text here.")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                .animation(.smooth(duration: 0.3), value: viewModel.body.isEmpty)
            }
            .background(Color(.systemBackground))
            .navigationTitle("New text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!viewModel.canSave)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    PasteButton(payloadType: String.self) { strings in
                        Task { @MainActor in
                            model.paste(strings)
                        }
                    }
                    .labelStyle(.titleAndIcon)

                    Spacer()

                    Text("\(viewModel.wordCount) words")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
        }
    }

    private func save() {
        guard let text = viewModel.makeText() else { return }
        withAnimation(.smooth(duration: 0.45)) {
            modelContext.insert(text)
        }
        dismiss()
    }
}

#Preview {
    AddTextView()
        .modelContainer(for: ReadingText.self, inMemory: true)
}
