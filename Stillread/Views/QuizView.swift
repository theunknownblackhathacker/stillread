// Stillread/Views/QuizView.swift

import SwiftUI

/// Comprehension quiz (spec §3): one question at a time, then a short summary.
struct QuizView: View {
    let viewModel: QuizViewModel
    let onClose: () -> Void
    let onReadAgain: () -> Void

    private let motion = Animation.smooth(duration: 0.45)

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if viewModel.isFinished {
                QuizSummaryView(viewModel: viewModel, onClose: onClose, onReadAgain: onReadAgain)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if let item = viewModel.current {
                question(item)
                    .id(item.id)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            }
        }
        .overlay(alignment: .top) { topBar }
        .animation(motion, value: viewModel.currentIndex)
        .animation(motion, value: viewModel.isFinished)
        .sensoryFeedback(.success, trigger: viewModel.correctCount)
        .sensoryFeedback(.error, trigger: viewModel.wrongCount)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 16) {
            CircleIconButton(systemImage: "xmark", accessibilityLabel: "Close", action: onClose)

            if !viewModel.isFinished {
                HStack(spacing: 6) {
                    ForEach(viewModel.items) { item in
                        Capsule()
                            .fill(item.id < viewModel.answeredCount ? Color.primary : Color.primary.opacity(0.15))
                            .frame(height: 4)
                    }
                }
                .animation(motion, value: viewModel.answeredCount)
                .accessibilityElement()
                .accessibilityLabel(Text("Question \(viewModel.currentIndex + 1) of \(viewModel.items.count)"))
                .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Question

    private func question(_ item: QuizItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Question \(item.id + 1) of \(viewModel.items.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(item.question)
                    .font(.title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    ForEach(item.options.indices, id: \.self) { index in
                        OptionButton(
                            text: item.options[index],
                            state: optionState(index, in: item)
                        ) {
                            viewModel.select(index)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 72)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            if viewModel.hasAnswered {
                PrimaryActionButton(
                    title: viewModel.isLastQuestion ? "See results" : "Next question",
                    systemImage: viewModel.isLastQuestion ? "flag.checkered" : "arrow.right"
                ) {
                    viewModel.next()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.35), value: viewModel.selectedOption)
    }

    private func optionState(_ index: Int, in item: QuizItem) -> OptionButton.OptionState {
        guard let selected = viewModel.selectedOption else { return .idle }
        if index == item.correctIndex { return .correct }
        if index == selected { return .wrong }
        return .dimmed
    }
}

// MARK: - Option

private struct OptionButton: View {
    enum OptionState {
        case idle
        case correct
        case wrong
        case dimmed
    }

    let text: String
    let state: OptionState
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(text)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if state == .correct {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .font(.title3)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(background, in: shape)
            .overlay(shape.strokeBorder(border, lineWidth: 1.5))
            .opacity(state == .dimmed ? 0.45 : 1)
            .contentShape(shape)
        }
        .buttonStyle(PressableCardStyle())
        .allowsHitTesting(state == .idle)
        .accessibilityAddTraits(state == .correct ? .isSelected : [])
    }

    private var background: Color {
        switch state {
        case .correct: .green.opacity(0.15)
        case .wrong: .red.opacity(0.15)
        case .idle, .dimmed: Color(.secondarySystemBackground)
        }
    }

    private var border: Color {
        switch state {
        case .correct: .green
        case .wrong: .red
        case .idle, .dimmed: .clear
        }
    }
}

// MARK: - Summary

private struct QuizSummaryView: View {
    let viewModel: QuizViewModel
    let onClose: () -> Void
    let onReadAgain: () -> Void

    @State private var shownScore = 0

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 6) {
                Text("\(shownScore) / \(viewModel.items.count)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("correct answers")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                StatTile(value: viewModel.wordsPerMinute, label: "Reading speed")
                StatTile(value: viewModel.effectiveWordsPerMinute, label: "Effective wpm")
            }

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Spacer()

            VStack(spacing: 12) {
                PrimaryActionButton(title: "Done", systemImage: "checkmark", action: onClose)
                SecondaryActionButton(title: "Read again", systemImage: "arrow.counterclockwise", action: onReadAgain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
        .onAppear {
            withAnimation(.smooth(duration: 0.9).delay(0.25)) {
                shownScore = viewModel.correctCount
            }
        }
    }

    private var message: LocalizedStringKey {
        switch viewModel.accuracy {
        case 1: "Perfect understanding."
        case 0.66...: "Good understanding. You kept most of the meaning."
        default: "Try a slightly slower speed to keep more of the meaning."
        }
    }
}

private struct StatTile: View {
    let value: Int
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 4) {
            Text(value, format: .number)
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
