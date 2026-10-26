// Stillread/Views/Components/Entrance.swift

import SwiftUI

extension View {
    /// Fades, rises and un-blurs into place when `visible` turns true.
    /// Stagger sections with increasing delays for a continuous, film-like entrance.
    /// With Reduce Motion on, it only fades.
    func entrance(_ visible: Bool, delay: Double) -> some View {
        modifier(EntranceModifier(visible: visible, delay: delay))
    }
}

private struct EntranceModifier: ViewModifier {
    let visible: Bool
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 18)
            .blur(radius: visible || reduceMotion ? 0 : 6)
            .animation(
                reduceMotion ? .easeOut(duration: 0.3) : .smooth(duration: 0.8).delay(delay),
                value: visible
            )
    }
}
