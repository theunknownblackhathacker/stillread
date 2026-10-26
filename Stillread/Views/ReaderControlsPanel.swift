// Stillread/Views/ReaderControlsPanel.swift

import SwiftUI

/// Mode picker and speed controls. Shown only while the reader is not playing.
struct ReaderControlsPanel: View {
    let viewModel: ReaderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Reading mode", selection: modeBinding) {
                ForEach(ReadingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(viewModel.mode.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(speedLabel)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .padding(.top, 4)

            Slider(value: speedBinding, in: sliderRange, step: 10)
                .tint(.primary)
                .accessibilityLabel(Text("Speed"))
                .accessibilityValue(Text("\(viewModel.wordsPerMinute) words per minute"))

            HStack(spacing: 8) {
                ForEach(ReaderViewModel.speedPresets, id: \.self) { preset in
                    PresetButton(value: preset, isSelected: preset == viewModel.wordsPerMinute) {
                        viewModel.setWordsPerMinute(preset)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var speedLabel: LocalizedStringKey {
        if viewModel.mode == .ramp {
            return "\(viewModel.rampStartWordsPerMinute) → \(viewModel.wordsPerMinute) wpm"
        }
        return "\(viewModel.wordsPerMinute) wpm"
    }

    private var sliderRange: ClosedRange<Double> {
        Double(ReaderViewModel.wpmRange.lowerBound)...Double(ReaderViewModel.wpmRange.upperBound)
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.wordsPerMinute) },
            set: { viewModel.setWordsPerMinute(Int($0.rounded())) }
        )
    }

    private var modeBinding: Binding<ReadingMode> {
        Binding(
            get: { viewModel.mode },
            set: { viewModel.setMode($0) }
        )
    }
}

private struct PresetButton: View {
    let value: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(value, format: .number.grouping(.never))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(isSelected ? 0.12 : 0), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(isSelected ? 0 : 0.15)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(value) words per minute"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
