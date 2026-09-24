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
        if let requested = selection.requested, let range = CharacterRange.of(requested, in: text) {
            let selected = NSRange(range, in: text)
            if view.selectedRange != selected {
                context.coordinator.applying = true
                view.selectedRange = selected
                context.coordinator.applying = false
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
            let range = Range(view.selectedRange, in: text)
            selection.text = range.map { String(text[$0]) } ?? ""
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
