import SwiftUI
import YomidoriCore

#if os(iOS)
import UIKit

/// Pasted text in place of a page: selectable as Live Text's page is, the selection reported
/// the same way, so the words under it read out as from a photo.
struct TextPage: UIViewRepresentable {
    let text: String
    @ObservedObject var selection: LiveTextSelection

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.font = .preferredFont(forTextStyle: .title2)
        view.adjustsFontForContentSizeCategory = true
        view.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        view.backgroundColor = UIColor(Palette.page)
        view.textColor = .label
        view.delegate = context.coordinator
        view.text = text
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        // The coordinator knows the new text before the view, and a selection reset by the
        // new text isn't published in the middle of this update (the page's own state is
        // cleared with it).
        context.coordinator.text = text
        if view.text != text {
            context.coordinator.applying = true
            view.text = text
            context.coordinator.applying = false
        }
        if let requested = selection.requested, selection.requestedPage == 0,
            let range = CharacterRange.of(requested, in: text)
        {
            let selected = NSRange(range, in: text)
            if view.selectedRange != selected {
                context.coordinator.applying = true
                view.selectedRange = selected
                context.coordinator.applying = false
                // Reported back all the same, once this update is over: otherwise the
                // selection kept is the older one, and choosing that word again in the
                // text would look like no change and go unreported.
                let coordinator = context.coordinator
                DispatchQueue.main.async { coordinator.report(view) }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: text, selection: selection)
    }

    @MainActor final class Coordinator: NSObject, UITextViewDelegate {
        var text: String
        private let selection: LiveTextSelection

        init(text: String, selection: LiveTextSelection) {
            self.text = text
            self.selection = selection
        }

        /// A selection being set from elsewhere, already known: not reported back.
        var applying = false

        func textViewDidChangeSelection(_ view: UITextView) {
            guard !applying else { return }
            report(view)
        }

        func report(_ view: UITextView) {
            let range = Range(view.selectedRange, in: text)
            selection.text = range.map { String(text[$0]) } ?? ""
            selection.rangePage = 0
            selection.range = range.map { range in
                let start = text.distance(from: text.startIndex, to: range.lowerBound)
                return start..<(start + text[range].count)
            }
        }
    }
}
#else
struct TextPage: View {
    let text: String
    let selection: LiveTextSelection

    var body: some View {
        ScrollView {
            Text(verbatim: text).font(.title2).textSelection(.enabled).padding()
        }
    }
}
#endif

#if os(macOS)
import AppKit

/// The Mac's page: a box the reader pastes or types the text into, and selects in, the
/// selection reported as Live Text's is on the phone, so the words under it read out.
struct TextBox: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var selection: LiveTextSelection
    /// Bumped to take the keyboard's focus.
    var focusAsked = 0

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let view = scroll.documentView as? NSTextView else { return scroll }
        view.isEditable = true
        view.isSelectable = true
        view.isRichText = false
        view.allowsUndo = true
        view.usesFindBar = true
        view.font = .systemFont(ofSize: NSFont.systemFontSize * 1.5)
        view.textContainerInset = NSSize(width: 20, height: 24)
        view.backgroundColor = NSColor(Palette.page)
        view.textColor = .labelColor
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.delegate = context.coordinator
        view.string = text
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor(Palette.page)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView else { return }
        if context.coordinator.focusAsked != focusAsked {
            context.coordinator.focusAsked = focusAsked
            DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        }
        context.coordinator.text = text
        if view.string != text {
            context.coordinator.applying = true
            view.string = text
            context.coordinator.applying = false
        }
        if let requested = selection.requested, selection.requestedPage == 0,
            let range = CharacterRange.of(requested, in: text)
        {
            let selected = NSRange(range, in: text)
            if view.selectedRange() != selected {
                context.coordinator.applying = true
                view.setSelectedRange(selected)
                view.scrollRangeToVisible(selected)
                context.coordinator.applying = false
                let coordinator = context.coordinator
                DispatchQueue.main.async { coordinator.report(view) }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selection: selection)
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var text: String
        private let bound: Binding<String>
        private let selection: LiveTextSelection
        /// A text or selection being set from here, already known: not reported back.
        var applying = false
        var focusAsked = 0

        init(text: Binding<String>, selection: LiveTextSelection) {
            self.text = text.wrappedValue
            bound = text
            self.selection = selection
        }

        func textDidChange(_ notification: Notification) {
            guard !applying, let view = notification.object as? NSTextView else { return }
            text = view.string
            bound.wrappedValue = view.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !applying, let view = notification.object as? NSTextView else { return }
            report(view)
        }

        func report(_ view: NSTextView) {
            let text = view.string
            let range = Range(view.selectedRange(), in: text)
            selection.text = range.map { String(text[$0]) } ?? ""
            selection.rangePage = 0
            selection.range = range.flatMap { range in
                guard !range.isEmpty else { return nil }
                let start = text.distance(from: text.startIndex, to: range.lowerBound)
                return start..<(start + text[range].count)
            }
        }
    }
}
#endif
