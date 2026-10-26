// Stillread/Views/Components/ChartPalette.swift

import SwiftUI
import UIKit

/// Chart series colours: slots 1 (blue) and 2 (orange) of a validated categorical palette,
/// with separate light and dark steps. Checked for colour-blind separation and contrast.
enum ChartPalette {
    static let series1 = Color(uiColor: UIColor(light: 0x2A78D6, dark: 0x3987E5))
    static let series2 = Color(uiColor: UIColor(light: 0xEB6834, dark: 0xD95926))
}

private extension UIColor {
    convenience init(light: UInt32, dark: UInt32) {
        self.init { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }

    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
