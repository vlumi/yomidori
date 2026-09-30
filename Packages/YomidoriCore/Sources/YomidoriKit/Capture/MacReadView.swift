import SwiftUI
import UniformTypeIdentifiers
import VisionKit
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
    /// With a picture: the picture itself, or its text as read.
    @State private var pictureAsReading = false
    /// The picture is being read by the recognizers.
    @State private var recognizing = false
    @State private var recognition: Task<Void, Never>?
    @State private var dropping = false
    @State private var opening = false
    @ObservedObject private var commands = AppCommands.shared

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
        // A picture dropped on the page, from a file or another app.
        .onDrop(of: [.image, .fileURL], isTargeted: $dropping) { providers in
            take(dropped: providers)
        }
        // File › Open…: a picture from a file.
        .onChange(of: commands.openAsked) { _, _ in opening = true }
        .fileImporter(isPresented: $opening, allowedContentTypes: [.image]) { result in
            guard let url = try? result.get() else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let still = Still(data: data) { take(still) }
        }
    }

    // MARK: The page

    @ViewBuilder private var pagePane: some View {
        VStack(spacing: 0) {
            pageBar
            Divider()
            if let still = page.still {
                if pictureAsReading, let reading = page.reading {
                    ReadingPage(
                        reading: reading, selection: selection, onPaste: pasteFromPasteboard)
                } else {
                    PictureView(still: still, analysis: page.analysis, selection: selection)
                        .background(
                            KeyCatcher(asked: 0) { code, modifiers in
                                code == 9 && modifiers == [.command] ? pasteFromPasteboard() : false
                            }
                        )
                        .overlay {
                            if recognizing {
                                ProgressView {
                                    Text("Reading the page…", bundle: .module)
                                }
                                .padding(20)
                                .background(
                                    .regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                }
            } else if editing || page.reading == nil {
                source
            } else if let reading = page.reading {
                ReadingPage(reading: reading, selection: selection, onPaste: pasteFromPasteboard)
            }
        }
        .overlay {
            if dropping {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Palette.nightGreen, lineWidth: 3)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
    }

    /// What the pane is showing, and the way to the other state.
    private var pageBar: some View {
        HStack {
            if page.still != nil {
                Text(pictureAsReading ? "Reading" : "Picture", bundle: .module)
                    .font(.headline)
                Spacer()
                if page.reading != nil {
                    Button {
                        pictureAsReading.toggle()
                    } label: {
                        Label {
                            Text(pictureAsReading ? "Picture" : "Reading", bundle: .module)
                        } icon: {
                            Image(systemName: pictureAsReading ? "photo" : "text.page")
                        }
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .help(Text("The picture, or its text as read (⌘↩)", bundle: .module))
                }
                Button {
                    clearPicture()
                } label: {
                    Label {
                        Text("Clear", bundle: .module)
                    } icon: {
                        Image(systemName: "xmark")
                    }
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .help(Text("Put the picture away (⌘⌫)", bundle: .module))
            } else if editing {
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
        TextBox(
            text: $draft, selection: selection, focusAsked: focusAsked,
            onPaste: {
                // A paste is a page arriving whole: it shows as its reading once read.
                readingAsked = true
            }, onPasteImage: take
        )
        .overlay(alignment: .topLeading) {
            if draft.isEmpty {
                Text(
                    "Paste the text you are reading here, or drop a picture of the page.",
                    bundle: .module
                )
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
                if let text = pageText {
                    TranscriptReadout(pageTexts: [text], selection: selection, showsStrip: false)
                } else if page.still != nil, !recognizing {
                    Text("Nothing was recognized.", bundle: .module)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
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
extension MacReadView {
    // MARK: A picture

    /// A picture in place of the text: read by both recognizers, Live Text's transcript
    /// being the page's text and its selection the picture's.
    private func take(_ still: Still) {
        recognition?.cancel()
        settling?.cancel()
        draft = ""
        selection.clear()
        selection.pageTexts = [:]
        page.newPage()
        page.pasted = nil
        page.pages = []
        page.analysis = nil
        page.lines = []
        page.transcript = nil
        page.still = still
        pictureAsReading = false
        editing = false
        recognizing = true
        recognition = Task { @MainActor in
            async let lines = (try? TextRecognizer.recognize(still)) ?? []
            async let analysis = LiveText.isSupported ? try? LiveText.analyze(still) : nil
            let (recognized, analyzed) = await (lines, analysis)
            guard !Task.isCancelled, page.still?.id == still.id else { return }
            page.lines = recognized
            page.analysis = analyzed
            recognizing = false
        }
    }

    private func take(dropped providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(for: .image) { data, _ in
                guard let data, let still = Still(data: data) else { return }
                DispatchQueue.main.async { take(still) }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil),
                    let file = try? Data(contentsOf: url), let still = Still(data: file)
                else { return }
                DispatchQueue.main.async { take(still) }
            }
            return true
        }
        return false
    }

    /// The pasteboard's picture, or its text into the box; for ⌘V while the page is no text
    /// box.
    private func pasteFromPasteboard() -> Bool {
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
            let still = Still(data: data)
        {
            take(still)
            return true
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
            let url = urls.first, let data = try? Data(contentsOf: url),
            let still = Still(data: data)
        {
            take(still)
            return true
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            clearPicture()
            draft = text
            readingAsked = true
            return true
        }
        return false
    }

    /// Back to an empty box.
    private func clearPicture() {
        recognition?.cancel()
        recognizing = false
        page.still = nil
        page.analysis = nil
        page.lines = []
        page.transcript = nil
        page.newPage()
        selection.clear()
        selection.pageTexts = [:]
        editing = true
        focusAsked += 1
    }

    /// The page's text: the box's, or the picture's as Live Text reads it, the overlay's own
    /// text once it has it, since its selection counts characters of that one.
    private var pageText: String? {
        if page.still != nil {
            if let analysis = page.analysis, analysis.hasResults(for: .text) {
                return selection.pageTexts[0] ?? analysis.transcript
            }
            // The page's own text, where it came with one (the demo's rendered page).
            return page.transcript
        }
        return page.pasted
    }
}
#endif
