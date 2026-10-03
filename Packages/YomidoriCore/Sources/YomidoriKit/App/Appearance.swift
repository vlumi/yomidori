import SwiftUI

/// The app's look: the device's, or light or dark regardless. Chosen in Settings and
/// applied at once, to every window of the app.
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// The scheme forced, nil to follow the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var label: Text {
        switch self {
        case .system: return Text("Same as the device", bundle: .module)
        case .light: return Text("Light", bundle: .module)
        case .dark: return Text("Dark", bundle: .module)
        }
    }
}

private struct ChosenAppearance: ViewModifier {
    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system

    func body(content: Content) -> some View {
        content.preferredColorScheme(appearance.colorScheme)
    }
}

extension View {
    /// The look chosen in Settings, on a window's root.
    public func chosenAppearance() -> some View {
        modifier(ChosenAppearance())
    }
}
