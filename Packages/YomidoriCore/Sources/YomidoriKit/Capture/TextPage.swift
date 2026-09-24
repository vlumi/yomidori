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
        if view.text != text { view.text = text }
        context.coordinator.text = text
        if let requested = selection.requested, requested.upperBound <= text.endIndex {
            let range = NSRange(requested, in: text)
            if view.selectedRange != range { view.selectedRange = range }
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

        func textViewDidChangeSelection(_ view: UITextView) {
            let range = Range(view.selectedRange, in: text)
            selection.text = range.map { String(text[$0]) } ?? ""
            selection.range = range
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
