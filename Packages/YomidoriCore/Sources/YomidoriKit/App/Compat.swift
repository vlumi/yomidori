import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Platform-only wrappers, no-ops where there is no UIKit (the macOS test build),
/// so views stay free of `#if`.
enum Clipboard {
    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}
