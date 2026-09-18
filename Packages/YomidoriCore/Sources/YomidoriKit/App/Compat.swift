import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension View {
    /// A navigation bar with no background, so the camera shows through; the
    /// modifier is iOS-only and the macOS test build has no bar to clear.
    func clearNavigationBar() -> some View {
        #if os(iOS)
        toolbarBackground(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}

/// Platform-only wrappers, no-ops where there is no UIKit (the macOS test build),
/// so views stay free of `#if`.
enum Clipboard {
    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}
