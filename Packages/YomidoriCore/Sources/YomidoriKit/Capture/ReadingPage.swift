import SwiftUI
import YomidoriCore

#if os(macOS)
import AppKit

/// The text as it was read, laid out as a page: every line as its chunks, the readings
/// over the words, the selection lit. A click selects a word, shift-click and the arrow
/// keys stretch or move the selection, Escape clears it.
struct ReadingPage: View {
    let reading: PageReading
    @ObservedObject var selection: LiveTextSelection
    /// ⌘V on the page: a new page from the pasteboard.
    var onPaste: () -> Bool = { false }
    @EnvironmentObject private var page: CaptureState
    /// Bumped to take the keys: on appearing, and on a click on the page.
    @State private var keysAsked = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(reading.lines.lines.indices, id: \.self) { line in
                    ChunkFlow(
                        chunks: reading.chunks.filter { $0.line == line },
                        selected: page.selectedRange,
                        select: { page.selectedRange = $0.range },
                        extend: page.extendSelection)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        // The page takes the keys: ← and → move the selection a word, with shift they
        // stretch it, Escape clears it. A click on the page brings the keys back to it.
        .background(KeyCatcher(asked: keysAsked, onKey: handle))
        .onTapGesture { keysAsked += 1 }
    }

    /// True when the key was the page's.
    private func handle(_ code: UInt16, _ modifiers: NSEvent.ModifierFlags) -> Bool {
        if code == 9, modifiers == [.command] { return onPaste() }
        guard modifiers.isSubset(of: [.shift]) else { return false }
        switch code {
        case 53:
            page.selectedRange = nil
            return true
        case 123: return move(-1, stretching: modifiers.contains(.shift))
        case 124: return move(1, stretching: modifiers.contains(.shift))
        default: return false
        }
    }

    /// The selection moved a word, or stretched by one, whichever way; with none, the
    /// first or the last word.
    private func move(_ step: Int, stretching: Bool) -> Bool {
        let words = reading.chunks.filter(\.isWord)
        guard !words.isEmpty else { return false }
        guard let range = page.selectedRange else {
            page.selectedRange = (step > 0 ? words.first : words.last)?.range
            return true
        }
        if stretching {
            let edge = step > 0 ? range.upperBound : range.lowerBound
            let next =
                step > 0
                ? words.first { $0.range.lowerBound >= edge }
                : words.last { $0.range.upperBound <= edge }
            if let next { page.extendSelection(to: next) }
        } else {
            let next =
                step > 0
                ? words.first { $0.range.lowerBound >= range.upperBound }
                : words.last { $0.range.upperBound <= range.lowerBound }
            if let next { page.selectedRange = next.range }
        }
        return true
    }
}

/// A view of no size that watches the window's keys while it is on screen and hands each
/// to a closure, which says whether it was taken; the rest go on as usual. A text view with
/// the focus keeps its keys.
struct KeyCatcher: NSViewRepresentable {
    var asked: Int
    let onKey: (UInt16, NSEvent.ModifierFlags) -> Bool

    final class Catcher: NSView {
        var onKey: (UInt16, NSEvent.ModifierFlags) -> Bool = { _, _ in false }
        var asked = 0
        private var monitor: Any?

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window, event.window === window,
                    !(window.firstResponder is NSTextView)
                else { return event }
                // The arrows carry the keypad and function flags of their own; only the
                // held keys count.
                let modifiers = event.modifierFlags.intersection([
                    .shift, .command, .option, .control,
                ])
                return self.onKey(event.keyCode, modifiers) ? nil : event
            }
        }
    }

    func makeNSView(context: Context) -> Catcher {
        let view = Catcher(frame: .zero)
        view.onKey = onKey
        return view
    }

    func updateNSView(_ view: Catcher, context: Context) {
        view.onKey = onKey
        if view.asked != asked {
            view.asked = asked
            // A click on the page takes the keys from whatever text field had them.
            DispatchQueue.main.async { view.window?.makeFirstResponder(nil) }
        }
    }
}
#endif
