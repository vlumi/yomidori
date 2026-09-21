import SwiftUI

public enum Palette {
    public static let nightGreen = Color(
        light: Color(red: 0.13, green: 0.42, blue: 0.32),
        dark: Color(red: 0.35, green: 0.68, blue: 0.55))
    public static let page = Color(
        light: Color(red: 0.98, green: 0.97, blue: 0.94),
        dark: Color(red: 0.06, green: 0.08, blue: 0.07))
    public static let silver = Color(
        light: Color(red: 0.55, green: 0.58, blue: 0.60),
        dark: Color(red: 0.78, green: 0.80, blue: 0.82))
}

extension Color {
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
