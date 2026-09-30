import SwiftUI
import YomidoriCore

#if os(macOS)
import AppKit

/// Reading on the Mac: the page on the left, big enough for a chapter, and the words of
/// whatever is selected in it on the right. No camera, no drawer.
///
/// The page is one pane with two states. *Source* is the text as pasted or typed, in a box.
/// *Reading* is the same text as it was read, the readings over the words, selectable by
/// click and shift-click and the arrow keys; it is what the strip under the words is on the
/// phone, made the page itself. A paste goes to reading by itself once read; *Edit* goes
/// back to the box, *Read* forward again.
public struct MacReadView: View {
    @EnvironmentObject private var page: CaptureState
    @EnvironmentObject private var taps: TabTaps
    @StateObject private var selection = LiveTextSelection()
    /// The box's text as typed; the page takes it once the typing pauses, cleaned.
    @State private var draft = ""
    @State private var settling: Task<Void, Never>?
    /// Bumped when Read is switched to: the box takes the focus, so what is pasted next
    /// lands in it without a click.
    @State private var focusAsked = 0
    /// The box is showing: the reader is putting the text in, or changing it.
    @State private var editing = true
    /// The text the reading came from was taken from the box just now: the pane goes to
    /// reading by itself when the reading arrives.
    @State private var readingAsked = false

    public init() {}

    public var body: some View {
        HSplitView {
            pagePane
                .frame(minWidth: 360, idealWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
            words
                .frame(minWidth: 320, idealWidth: 400, maxWidth: 560, maxHeight: .infinity)
        }
        .background(Palette.page)
        .onAppear {
            draft = page.pasted ?? ""
            editing = page.reading == nil
        }
        .onChange(of: draft) { _, typed in settle(typed) }
        .onChange(of: taps.shown, initial: true) { _, shown in
            if shown == .read, editing { focusAsked += 1 }
        }
        // The reading is in: a page just pasted shows as its reading.
        .onChange(of: page.reading == nil) { _, none in
            if !none, readingAsked {
                readingAsked = false
                editing = false
            }
        }
    }

    // MARK: The page

    @ViewBuilder private var pagePane: some View {
        VStack(spacing: 0) {
            pageBar
            Divider()
            if editing || page.reading == nil {
                source
            } else if let reading = page.reading {
                ReadingPage(reading: reading, selection: selection)
            }
        }
    }

    /// What the pane is showing, and the way to the other state.
    private var pageBar: some View {
        HStack {
            if editing {
                Text("Text", bundle: .module)
                    .font(.headline)
                Spacer()
                if page.reading != nil, page.pasted == cleanedDraft {
                    Button {
                        editing = false
                    } label: {
                        Label {
                            Text("Read", bundle: .module)
                        } icon: {
                            Image(systemName: "text.page")
                        }
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .help(Text("Show the text as read (⌘↩)", bundle: .module))
                }
            } else {
                Text("Reading", bundle: .module)
                    .font(.headline)
                Spacer()
                Button {
                    editing = true
                    focusAsked += 1
                } label: {
                    Label {
                        Text("Edit", bundle: .module)
                    } icon: {
                        Image(systemName: "pencil")
                    }
                }
                .keyboardShortcut("e", modifiers: .command)
                .help(Text("Change the text (⌘E)", bundle: .module))
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var source: some View {
        TextBox(text: $draft, selection: selection, focusAsked: focusAsked) {
            // A paste is a page arriving whole: it shows as its reading once read.
            readingAsked = true
        }
        .overlay(alignment: .topLeading) {
            if draft.isEmpty {
                Text("Paste the text you are reading here.", bundle: .module)
                    .font(.title3)
                    .foregroundStyle(Palette.silver)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 24)
                    .allowsHitTesting(false)
            }
        }
    }

    private var cleanedDraft: String? {
        let cleaned = Sanitize.text(draft, limit: CaptureView.longestPaste, keepsNewlines: true)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : cleaned
    }

    // MARK: The words

    /// The words on the right: the selection's.
    private var words: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                if let pasted = page.pasted {
                    TranscriptReadout(pageTexts: [pasted], selection: selection, showsStrip: false)
                } else {
                    Text("Select a word in the text, and it reads out here.", bundle: .module)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .tint(Palette.nightGreen)
    }

    /// Typing pauses, and the page is the text as it stands: cleaned and cut as a paste on
    /// the phone is, but not trimmed, since the selection counts characters of the box's
    /// own text and the two must be one; what cleaning took out goes from the box too. The
    /// selection is let go, its offsets being the old text's.
    private func settle(_ typed: String) {
        settling?.cancel()
        settling = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let cleaned = Sanitize.text(typed, limit: CaptureView.longestPaste, keepsNewlines: true)
            if cleaned != typed { draft = cleaned }
            let blank = cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let text: String? = blank ? nil : cleaned
            guard text != page.pasted else { return }
            selection.clear()
            page.selectedRange = nil
            page.still = nil
            page.pages = []
            page.pasted = text
            if text == nil { readingAsked = false }
        }
    }
}

/// The text as it was read, laid out as a page: every line as its chunks, the readings
/// over the words, the selection lit. A click selects a word, shift-click and the arrow
/// keys stretch or move the selection, Escape clears it.
struct ReadingPage: View {
    let reading: PageReading
    @ObservedObject var selection: LiveTextSelection
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
