import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension View {
    func clearNavigationBar() -> some View {
        #if os(iOS)
        toolbarBackground(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    func navigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
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

extension View {
    /// The phone's search field, the system's in the navigation bar; the Mac's is the
    /// dictionary column's own, so nothing here.
    func phoneSearchField(
        text: Binding<String>, focused: FocusState<Bool>.Binding,
        selection: Binding<TextSelection?>
    ) -> some View {
        #if os(iOS)
        searchable(text: text, prompt: Text("Kana, kanji, or English", bundle: .module))
            .searchFocused(focused)
            .searchSelection(selection)
        #else
        self
        #endif
    }

    /// Room under a list for the phone's search bar while it floats over the keyboard: the
    /// list clears the keyboard on its own, but not the bar above it, so the last row
    /// sprang back under the bar. Nothing on the Mac, whose field is in the column.
    func phoneSearchBarMargin(_ searching: Bool) -> some View {
        #if os(iOS)
        contentMargins(.bottom, searching ? 64 : 0, for: .scrollContent)
        #else
        self
        #endif
    }

    /// A split held to the width it is given: left to itself, a split of the Mac's reports
    /// the width its columns would like, and a window narrower than that is not what it
    /// is laid out to; the content overflows and the sections' sidebar is clipped.
    func fittingWindow() -> some View {
        GeometryReader { geometry in
            frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    /// A reading width: at most 640 points, centered, so a sentence in a wide window reads
    /// as on a page; no narrower than the phone.
    func readingWidth() -> some View {
        frame(maxWidth: 640).frame(maxWidth: .infinity)
    }

    /// A sheet's size on the Mac, where detents mean nothing and a sheet is as big as its
    /// content; nothing on the phone, whose sheets have their detents.
    func sheetSize(width: CGFloat, height: CGFloat) -> some View {
        #if os(macOS)
        frame(width: width, height: height)
        #else
        self
        #endif
    }

    /// A settings form as the Mac lays one out, grouped and scrolling; the phone's list is
    /// its own.
    func settingsFormStyle() -> some View {
        #if os(macOS)
        formStyle(.grouped)
        #else
        self
        #endif
    }
}

/// The system's pasteboard, whichever the platform has, so views stay free of `#if`.
enum Clipboard {
    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
