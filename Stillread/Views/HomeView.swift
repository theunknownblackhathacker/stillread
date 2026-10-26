// Stillread/Views/HomeView.swift

import SwiftUI
import SwiftData

/// Main screen: the library. Each card zooms into the reader (and back) with the
/// system zoom transition, which is interactive and runs at 120 Hz.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReadingText.createdAt, order: .reverse) private var texts: [ReadingText]
    @AppStorage("reader.wordsPerMinute") private var wordsPerMinute = 350

    @State private var openReader: OpenReader?
    @State private var isAddingText = false
    @State private var hasAppeared = false
    @Namespace private var zoom

    private let listAnimation = Animation.smooth(duration: 0.45)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                    .entrance(hasAppeared, delay: 0)

                Group {
                    if texts.isEmpty {
                        emptyState
                            .transition(.opacity)
                    } else {
                        library
                    }
                }
                .entrance(hasAppeared, delay: 0.1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemBackground))
        .fullScreenCover(item: $openReader) { reader in
            ReaderScreen(text: reader.text, viewModel: reader.viewModel)
                .navigationTransition(.zoom(sourceID: reader.id, in: zoom))
        }
        .sheet(isPresented: $isAddingText) {
            AddTextView()
        }
        .task {
            LibrarySeeder.seedIfNeeded(in: modelContext)
        }
        .onAppear { hasAppeared = true }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Stillread")
                    .font(.largeTitle.weight(.bold))
                Text("Read with a quiet mind.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isAddingText = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityLabel(Text("Add text"))
        }
    }

    private var library: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            Text("Library")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(texts) { text in
                Button {
                    open(text)
                } label: {
                    LibraryCard(text: text, wordsPerMinute: wordsPerMinute)
                }
                .buttonStyle(PressableCardStyle())
                .matchedTransitionSource(id: text.id, in: zoom)
                .contextMenu {
                    if text.lastWordIndex > 0 {
                        Button {
                            withAnimation(listAnimation) { text.lastWordIndex = 0 }
                        } label: {
                            Label("Start over", systemImage: "arrow.counterclockwise")
                        }
                    }
                    Button(role: .destructive) {
                        withAnimation(listAnimation) { modelContext.delete(text) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(listAnimation, value: texts.map(\.id))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.page")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)

            Text("Your library is empty")
                .font(.title3.weight(.semibold))

            Text("Paste an article, a chapter or any text you want to read faster.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                isAddingText = true
            } label: {
                Label("Add text", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(Color(.systemBackground))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.primary, in: Capsule())
            }
            .buttonStyle(PressableCardStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func open(_ text: ReadingText) {
        let viewModel = ReaderViewModel(title: text.title, text: text.body, startWord: text.lastWordIndex)
        openReader = OpenReader(text: text, viewModel: viewModel)
    }
}

/// The text being read plus its reader state. Created once per opening,
/// so the text is only tokenized when the reader actually opens.
private struct OpenReader: Identifiable {
    let text: ReadingText
    let viewModel: ReaderViewModel
    var id: UUID { text.id }
}

// MARK: - Card

private struct LibraryCard: View {
    let text: ReadingText
    let wordsPerMinute: Int

    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(text.excerpt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if text.isInProgress {
                ReadingProgressBar(value: text.progress)
                    .transition(.opacity)
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: text.source.symbolName)
                        Text(text.source.label)
                        Text(verbatim: "·")
                        Text(text.createdAt, format: .dateTime.day().month(.abbreviated))
                    }
                    Text("\(text.wordCount) words · ~\(text.estimatedMinutes(atWordsPerMinute: wordsPerMinute)) min")
                        .monospacedDigit()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Label(actionTitle, systemImage: text.isFinished ? "arrow.counterclockwise" : "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .foregroundStyle(Color(.systemBackground))
                    .background(Color.primary, in: Capsule())
                    .fixedSize()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: shape)
        .contentShape(shape)
        .animation(.smooth(duration: 0.45), value: text.lastWordIndex)
    }

    private var actionTitle: LocalizedStringKey {
        if text.isFinished { return "Read again" }
        if text.isInProgress { return "Continue" }
        return "Read"
    }
}

private extension View {
    /// Fades, rises and un-blurs into place the first time the screen appears.
    func entrance(_ visible: Bool, delay: Double) -> some View {
        opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .blur(radius: visible ? 0 : 6)
            .animation(.smooth(duration: 0.8).delay(delay), value: visible)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: ReadingText.self, inMemory: true)
}
