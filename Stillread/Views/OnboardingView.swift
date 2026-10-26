// Stillread/Views/OnboardingView.swift

import SwiftUI

/// First-launch introduction: how RSVP works, the red anchor, an honest note on the
/// inner voice, and a starting speed. Shown again from Settings → Show introduction.
struct OnboardingView: View {
    let onFinish: () -> Void

    @AppStorage(SettingsKey.wordsPerMinute) private var wordsPerMinute = ReaderDefaults.wordsPerMinute
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page = 0
    @State private var demo = ReaderViewModel(
        title: "",
        text: String(localized: "Words appear one at a time, right where your eyes already are. Just let them arrive.")
    )

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pageCount - 1 {
                    Button("Skip") { finish() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            TabView(selection: $page) {
                welcomePage.tag(0)
                anchorPage.tag(1)
                innerVoicePage.tag(2)
                speedPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 20) {
                PageDots(count: pageCount, current: page)

                PrimaryActionButton(
                    title: page == pageCount - 1 ? "Start reading" : "Continue",
                    systemImage: page == pageCount - 1 ? "book" : "arrow.right"
                ) {
                    if page == pageCount - 1 {
                        finish()
                    } else {
                        withAnimation(reduceMotion ? .none : .smooth(duration: 0.45)) { page += 1 }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
        .animation(.smooth(duration: 0.3), value: page)
        .onAppear { demo.togglePlayback() }
        .onDisappear { demo.pause() }
        .onChange(of: page) { _, newPage in
            if newPage == 0 {
                if !demo.isPlaying { demo.togglePlayback() }
            } else {
                demo.pause()
            }
        }
        .onChange(of: demo.state) { _, state in
            guard state == .finished else { return }
            // Loop the demo after a short rest.
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                if page == 0, demo.state == .finished { demo.togglePlayback() }
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        OnboardingPage(
            title: "Read one word at a time",
            message: "Stillread shows each word in the same place, so your eyes can stay still and the words come to you. Tap to pause, swipe right to go back a sentence."
        ) {
            RSVPWordView(parts: demo.currentParts)
                .frame(height: 140)
                .transaction { $0.animation = nil }
        }
    }

    private var anchorPage: some View {
        OnboardingPage(
            title: "Keep your eyes on the red letter",
            message: "The red letter marks the point where each word is easiest to recognise. Short pauses at commas and full stops give your mind time to keep up."
        ) {
            RSVPWordView(parts: OptimalRecognitionPoint.split(String(localized: "recognise")))
                .frame(height: 140)
        }
    }

    private var innerVoicePage: some View {
        OnboardingPage(
            title: "Quiet the inner voice",
            message: "Most of us read by saying words in our head. At higher speeds that voice can't keep up, and it starts to fade. It never disappears completely, and that's fine. Short quizzes help you check that the meaning still arrives."
        ) {
            Image(systemName: "waveform")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.secondary)
                .symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeating, isActive: !reduceMotion)
                .frame(height: 140)
                .accessibilityHidden(true)
        }
    }

    private var speedPage: some View {
        OnboardingPage(
            title: "Choose your starting speed",
            message: "You can change it at any time, in the reader or in Settings."
        ) {
            VStack(spacing: 10) {
                SpeedOption(value: 250, title: "Relaxed", isSelected: wordsPerMinute == 250) { wordsPerMinute = 250 }
                SpeedOption(value: 350, title: "Comfortable", isSelected: wordsPerMinute == 350) { wordsPerMinute = 350 }
                SpeedOption(value: 500, title: "Brisk", isSelected: wordsPerMinute == 500) { wordsPerMinute = 500 }
            }
            .padding(.horizontal, 4)
        }
    }

    private func finish() {
        demo.pause()
        onFinish()
    }
}

// MARK: - Building blocks

private struct OnboardingPage<Visual: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder let visual: () -> Visual

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

                visual()

                VStack(spacing: 12) {
                    Text(title)
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct SpeedOption: View {
    let value: Int
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text("\(value) wpm")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground), in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(isSelected ? 0.6 : 0), lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.smooth(duration: 0.25), value: isSelected)
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.primary : Color.primary.opacity(0.2))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(.smooth(duration: 0.35), value: current)
        .accessibilityElement()
        .accessibilityLabel(Text("Page \(current + 1) of \(count)"))
    }
}

#Preview {
    OnboardingView {}
}
