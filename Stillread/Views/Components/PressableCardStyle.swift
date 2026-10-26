// Stillread/Views/Components/PressableCardStyle.swift

import SwiftUI

/// Cards sink slightly under the finger, then spring back.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.smooth(duration: 0.25), value: configuration.isPressed)
    }
}
