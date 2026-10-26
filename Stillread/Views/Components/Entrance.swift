// Stillread/Views/Components/Entrance.swift

import SwiftUI

extension View {
    /// Fades, rises and un-blurs into place when `visible` turns true.
    /// Stagger sections with increasing delays for a continuous, film-like entrance.
    func entrance(_ visible: Bool, delay: Double) -> some View {
        opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .blur(radius: visible ? 0 : 6)
            .animation(.smooth(duration: 0.8).delay(delay), value: visible)
    }
}
