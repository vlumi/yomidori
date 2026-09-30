import SwiftUI
import YomidoriCore

#if os(macOS)
/// Reading on the Mac: the text pasted into a box on the left, big enough for a chapter,
/// and the words of whatever is selected in it on the right. No camera, no drawer.
public struct MacReadView: View {
    @EnvironmentObject private var page: CaptureState
    @StateObject private var selection = LiveTextSelection()
    /// The box's text as typed; the page takes it once the typing pauses, cleaned.
    @State private var draft = ""
    @State private var settling: Task<Void, Never>?

    public init() {}

    public var body: some View {
        HSplitView {
            VSplitView {
                TextBox(text: $draft, selection: selection)
                    .frame(minWidth: 360, idealWidth: 560, maxWidth: .infinity)
                    .frame(minHeight: 200, maxHeight: .infinity)
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
                // The text as it was read, with the readings over the words: the left
                // side's, under the box it is the reading of.
                if let reading = page.reading {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                            RecognizedTextStrip(reading: reading)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                    .frame(minHeight: 44, idealHeight: 220)
                }
            }
            words
                .frame(minWidth: 320, idealWidth: 400, maxWidth: 560, maxHeight: .infinity)
        }
        .background(Palette.page)
        .onAppear { draft = page.pasted ?? "" }
        .onChange(of: draft) { _, typed in settle(typed) }
    }

    /// The words on the right: the selection's, and the recognized-text strip under them.
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
        }
    }
}
#endif
