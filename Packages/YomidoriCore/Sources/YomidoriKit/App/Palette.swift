import SwiftUI

/// The app's colors, one set for each appearance. 夜緑 — night green — is the
/// accent and the frame in both; pages and cards sit on neutral ground so the
/// reading is what the eye lands on.
public enum Palette {
    /// The accent: highlighted word, buttons, the bird.
    public static let nightGreen = Color(
        light: Color(red: 0.13, green: 0.42, blue: 0.32),
        dark: Color(red: 0.35, green: 0.68, blue: 0.55))
    /// The ground behind text: paper by day, near-black by night.
    public static let page = Color(
        light: Color(red: 0.98, green: 0.97, blue: 0.94),
        dark: Color(red: 0.06, green: 0.08, blue: 0.07))
    /// The silver of the mascot, for secondary marks.
    public static let silver = Color(
        light: Color(red: 0.55, green: 0.58, blue: 0.60),
        dark: Color(red: 0.78, green: 0.80, blue: 0.82))
}

extension Color {
    /// A color that follows the appearance, resolved by UIKit on iOS and fixed to
    /// the light value where there is no UIKit (the macOS test build).
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(
            uiColor: UIColor { traits in
                UIColor(traits.userInterfaceStyle == .dark ? dark : light)
            })
        #else
        self = light
        #endif
    }
}
