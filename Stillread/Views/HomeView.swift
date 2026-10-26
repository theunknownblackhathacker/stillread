// Stillread/Views/HomeView.swift

import SwiftUI

/// Main screen. The text card zooms into the reader (and back) with the
/// system zoom transition, which is interactive and runs at 120 Hz.
/// In Milestone 3 the single card becomes the library list.
struct HomeView: View {
    @State private var reader = ReaderViewModel(title: SampleText.title, text: SampleText.body)
    @State private var isReading = false
    @State private var hasAppeared = false
    @Namespace private var zoom

    private let sampleID = "sample-text"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                    .entrance(hasAppeared, delay: 0)

                VStack(alignment: .leading, spacing: 12) {
                    Text(sectionTitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)

                    Button {
                        isReading = true
                    } label: {
                        TextCard(reader: reader)
                    }
                    .buttonStyle(PressableCardStyle())
                    .matchedTransitionSource(id: sampleID, in: zoom)
                }
                .entrance(hasAppeared, delay: 0.1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemBackground))
        .fullScreenCover(isPresented: $isReading) {
            ReaderView(viewModel: reader)
                .navigationTransition(.zoom(sourceID: sampleID, in: zoom))
        }
        .onAppear { hasAppeared = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stillread")
                .font(.largeTitle.weight(.bold))
            Text("Read with a quiet mind.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var sectionTitle: LocalizedStringKey {
        reader.hasStarted ? "Continue reading" : "Start here"
    }
}

private struct TextCard: View {
    let reader: ReaderViewModel

    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(reader.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text(reader.excerpt)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            if reader.hasStarted {
                ReadingProgressBar(value: reader.displayProgress)
                    .transition(.opacity)
            }

            HStack(alignment: .center) {
                Text("\(reader.words.count) words · \(timeText) left")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Label(actionTitle, systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .foregroundStyle(Color(.systemBackground))
                    .background(Color.primary, in: Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: shape)
        .contentShape(shape)
    }

    private var timeText: String {
        Duration.seconds(reader.secondsRemaining).formatted(.time(pattern: .minuteSecond))
    }

    private var actionTitle: LocalizedStringKey {
        switch reader.state {
        case .finished: "Read again"
        case .ready: reader.hasStarted ? "Continue" : "Read"
        case .playing, .paused: "Continue"
        }
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
}
