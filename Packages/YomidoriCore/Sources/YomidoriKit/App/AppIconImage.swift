import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The app's own icon, as the bundle carries it, at a size; nothing when the bundle has
/// none (the tests).
struct AppIconImage: View {
    let side: CGFloat

    var body: some View {
        if let image = Self.image {
            image
                .resizable()
                .interpolation(.high)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    private static var image: Image? {
        #if canImport(UIKit)
        // The icon files are compiled under the names Info.plist lists.
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String], let name = files.last,
            let icon = UIImage(named: name)
        else { return nil }
        return Image(uiImage: icon)
        #elseif canImport(AppKit)
        return Image(nsImage: NSApplication.shared.applicationIconImage)
        #else
        return nil
        #endif
    }
}
