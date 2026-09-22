import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension View {
    func clearNavigationBar() -> some View {
        #if os(iOS)
        toolbarBackground(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

}

extension View {
    /// The bar collapses into its compact pill when the content scrolls down.
    func minimizingTabBarOnScroll() -> some View {
        #if os(iOS)
        tabBarMinimizeBehavior(.onScrollDown)
        #else
        self
        #endif
    }
}

/// No-ops where there is no UIKit, so views stay free of `#if`.
enum Clipboard {
    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}
