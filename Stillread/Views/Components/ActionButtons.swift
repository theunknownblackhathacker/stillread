// Stillread/Views/Components/ActionButtons.swift

import SwiftUI

/// Full-width filled button (primary colour on background colour, so it works in light and dark).
struct PrimaryActionButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var isLoading = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(Color(.systemBackground))
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.primary.opacity(isEnabled ? 1 : 0.25), in: Capsule())
            .contentShape(Capsule())
            .animation(.smooth(duration: 0.3), value: isLoading)
        }
        .buttonStyle(PressableCardStyle())
        .allowsHitTesting(isEnabled && !isLoading)
    }
}

/// Full-width outlined button.
struct SecondaryActionButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.2)))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableCardStyle())
    }
}

/// Round icon button used in headers and top bars.
struct CircleIconButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
                .background(Color(.secondarySystemBackground), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(Text(accessibilityLabel))
    }
}
