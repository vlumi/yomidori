import SwiftUI
import YomidoriCore
import YomidoriDictionary
import YomidoriMeCab

/// The drawer under a page: the words selected, and the page's text as its chunks. The page is
/// read into words once (`PageReading`), when its text is known or changes, and a selection
/// is a range of that text, made on the page, in the strip or on the picture alike.
struct TranscriptReadout: View {
    /// The spread's pages' texts in reading order; read as one, joined at the seams.
    let pageTexts: [String]
    @ObservedObject var selection: LiveTextSelection
    /// The recognized-text strip under the words; off where it stands elsewhere, as on
    /// the Mac, beside the text it is the reading of.
    var showsStrip = true
    @EnvironmentObject private var page: CaptureState
    @AppStorage(TokenizerChoice.key) private var choice: TokenizerChoice = .system
    /// The words with a card, as "headword reading", read with the page and added to by Keep.
    @State private var keptWords: Set<String> = []
    /// The words whose sentence on this page is on their card: kept or added here.
    @State private var addedHere: Set<String> = []
    /// The card opened from a kept word's mark, over the page.
    @State private var openedCard: Card?
    /// Where the selection goes once a fix has been read in.
    @State private var afterFix: Range<Int>?

    /// Laid straight into the drawer's lazy stack, so the recognized text's title, a section
    /// header, stays at the top while its lines scroll under it.
    var body: some View {
        Group {
            // The page's own work hangs off the header, which is always in the lazy stack's
            // view; a view of no size at the end is not made while the drawer is short, and
            // the page would never be read.
            header
                .task(id: ReadKey(choice: choice, texts: pageTexts, fixes: page.fixes)) {
                    await read()
                }
                .onChange(of: selection.range) { selectionOnPage() }
                .onChange(of: page.selectedRange) { _, range in
                    requestOnPage(range)
                    noteLookups(range)
                }
                .sheet(item: $openedCard) { card in
                    CardSheet(card: card)
                        .sheetSize(width: 560, height: 700)
                }
            if page.reading == nil {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading the words…", bundle: .module)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            } else if let reading = page.reading, let range = page.selectedRange {
                selectionRows(reading, range)
            }
            if choice == .mecab, MeCabTokenizer.shared == nil {
                Text("MeCab could not load its dictionary.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            if showsStrip, let reading = page.reading {
                RecognizedTextStrip(reading: reading)
            }
        }
    }

    /// Several chunks: the phrase first, looked up whole when the dictionary knows it, then
    /// each word. One chunk: its word.
    @ViewBuilder private func selectionRows(_ reading: PageReading, _ range: Range<Int>)
        -> some View
    {
        let chunks = reading.chunks(in: range)
        let words = chunks.filter(\.isWord)
        let sentence = reading.sentence(around: range)
        if !sentence.isEmpty {
            SpeakButton(text: sentence)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        if chunks.count > 1 {
            PhraseRow(
                reading: reading, chunks: chunks, fix: fixer(for: range, in: reading),
                kept: { keptWords.contains($0.wordKey) },
                added: { addedHere.contains($0.wordKey) },
                open: { openedCard = Self.card(of: $0) }
            ) {
                keep($0, onLine: chunks[0].line, in: reading)
            }
            if !words.isEmpty { Divider() }
        }
        ForEach(words) { chunk in
            if chunk.id != words.first?.id { Divider() }
            wordReadout(chunk, in: reading)
            partReadouts(chunk, in: reading)
        }
    }

    /// Under a word joined from several, the words it is made of, each to read and to keep
    /// by itself: 木馬 under トロイの木馬, where the reader wanted the one word.
    @ViewBuilder private func partReadouts(_ chunk: PageReading.Chunk, in reading: PageReading)
        -> some View
    {
        // Each part's row under its own word's id: by its place alone, every word's first
        // part was row 0 to the lazy stack, and a row from the selection before could stay
        // on under the next word, unchanged.
        let rows = chunk.parts.enumerated().map {
            PartRow(id: "\(chunk.id).\($0.offset)", part: $0.element)
        }
        ForEach(rows) { row in
            let part = row.part
            WordReadout(
                word: part,
                accent: part.entries.first.flatMap { JMdict.bundled?.pitchAccent(of: $0) },
                estimate: part.entries.first.flatMap { JMdict.bundled?.estimatedPitch(of: $0) }
                    ?? [],
                kept: keptWords.contains(part.wordKey),
                added: addedHere.contains(part.wordKey), canKeep: Cards.store != nil,
                fix: nil,
                open: { openedCard = Self.card(of: part) }
            ) {
                keep(part, onLine: chunk.line, in: reading)
            }
            .padding(.leading, 18)
            // A bar down the side says these belong to the word above.
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Palette.nightGreen.opacity(0.45))
                    .frame(width: 2)
            }
        }
    }

    private func wordReadout(_ chunk: PageReading.Chunk, in reading: PageReading) -> some View {
        WordReadout(
            word: chunk.word,
            accent: chunk.word.entries.first.flatMap { JMdict.bundled?.pitchAccent(of: $0) },
            estimate: chunk.word.entries.first.flatMap { JMdict.bundled?.estimatedPitch(of: $0) }
                ?? [],
            kept: keptWords.contains(chunk.word.wordKey),
            added: addedHere.contains(chunk.word.wordKey), canKeep: Cards.store != nil,
            fix: fixer(for: chunk.range, in: reading),
            open: { openedCard = Self.card(of: chunk.word) }
        ) {
            keep(chunk.word, onLine: chunk.line, in: reading)
        }
    }

    private var copies: Bool {
        #if os(macOS)
        page.still != nil
        #else
        true
        #endif
    }

    private var header: some View {
        HStack {
            CollectionPicker()
                .controlSize(.small)
            Spacer()
            tokenizerMenu
            // Not for the Mac's typed text, which is in a box already; a picture's text
            // has no box on either platform.
            if copies {
                Button {
                    Clipboard.copy(page.fixes.matching(pageTexts).fixedText)
                } label: {
                    Label {
                        Text("Copy", bundle: .module)
                    } icon: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(Text("Copy the recognized text", bundle: .module))
            }
        }
    }

    /// The analyzer, switched right here so the same page can be cut both ways.
    @ViewBuilder private var tokenizerMenu: some View {
        #if os(macOS)
        // A pop-up button: a menu holding a picker would be a submenu here.
        Picker(selection: $choice) {
            Text("System", bundle: .module).tag(TokenizerChoice.system)
            Text(verbatim: "MeCab").tag(TokenizerChoice.mecab)
        } label: {
            Text("Tokenizer", bundle: .module)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .accessibilityLabel(Text("Tokenizer", bundle: .module))
        #else
        Menu {
            Picker(selection: $choice) {
                Text("System", bundle: .module).tag(TokenizerChoice.system)
                Text(verbatim: "MeCab").tag(TokenizerChoice.mecab)
            } label: {
                Text("Tokenizer", bundle: .module)
            }
        } label: {
            Label {
                Text(choice == .system ? "System" : "MeCab", bundle: .module)
            } icon: {
                Image(systemName: "text.word.spacing")
            }
            .font(.footnote)
        }
        .controlSize(.small)
        .accessibilityLabel(Text("Tokenizer", bundle: .module))
        .accessibilityValue(Text(choice == .system ? "System" : "MeCab", bundle: .module))
        #endif
    }

    private var transcript: String {
        Spread.join(pageTexts)
    }

    /// Where a page starts in the joined text, in characters.
    private func offset(ofPage index: Int) -> Int {
        Spread.offset(ofPage: index, in: pageTexts)
    }

    /// What a reading is of: the page texts, the fixes and the tokenizer; another of any
    /// and the page is read again. Compared whole, which is a memcmp of the texts, where the
    /// fixed text as a key was built — trimmed, fixed and joined — on every render.
    private struct ReadKey: Equatable {
        let choice: TokenizerChoice
        let texts: [String]
        let fixes: SpreadFixes
    }

    /// The page read into words, off the main thread; taps wait until it is done.
    /// Not again for a page already read this way: a return to the tab keeps the reading
    /// and the selection.
    private func read() async {
        let current = page.fixes.matching(pageTexts)
        if current != page.fixes { page.fixes = current }
        let text = current.fixedText
        let key = "\(choice)|\(text)"
        guard page.reading == nil || page.readingKey != key else {
            selection.looking = false
            return
        }
        let previous = afterFix ?? page.selectedRange
        page.reading = nil
        selection.looking = true
        let reading = await PageReader.shared.read(text, with: choice)
        guard !Task.isCancelled else { return }
        keptWords = Cards.keptWords()
        addedHere = []
        page.reading = reading
        page.readingKey = key
        page.selectedRange = previous.flatMap(reading.whole)
        afterFix = nil
        selection.looking = false
        // A word selected on the page while it was being read is taken up now.
        if page.selectedRange == nil { selectionOnPage() }
    }

    private static func card(of word: FoundWord) -> Card? {
        Cards.store?.cards().first { $0.wordKey == word.wordKey }
    }

    /// Corrects one character of a word and reads the page again, the selection kept on it,
    /// so the readout, Keep's sentence and the copy all read as corrected.
    private func fix(_ fixed: Range<Int>, _ change: PageFix) {
        let fix: TextFix
        switch change {
        case .character(let index, let replacement):
            fix = TextFix(offset: fixed.lowerBound + index, length: 1, replacement: replacement)
        case .whole(let replacement):
            fix = TextFix(replacing: fixed, with: replacement)
        }
        guard page.fixes.add(fix) else { return }
        let range = page.selectedRange ?? fixed
        afterFix =
            range
            .lowerBound..<max(
                range.lowerBound, range.upperBound + fix.replacement.count - fix.length)
    }

    /// The way to put a run of the page right, where it lies on one line: a run over a line
    /// break is two pieces of text, and is fixed a piece at a time.
    private func fixer(for range: Range<Int>, in reading: PageReading) -> ((PageFix) -> Void)? {
        guard !range.isEmpty, range.lowerBound >= 0, range.upperBound <= reading.text.count,
            !reading.spansLines(range)
        else { return nil }
        return { fix(range, $0) }
    }

    /// A selection made on the page itself (Live Text's, the pasted text's), as whole chunks.
    private func selectionOnPage() {
        let onPage = selection.rangePage
        guard let reading = page.reading, let range = selection.range,
            pageTexts.indices.contains(onPage),
            range.lowerBound >= 0, range.upperBound <= pageTexts[onPage].count
        else { return }
        let start = offset(ofPage: onPage)
        let mapped = page.fixes.map((start + range.lowerBound)..<(start + range.upperBound))
        guard !mapped.isEmpty, let whole = reading.whole(mapped), whole != page.selectedRange else {
            return
        }
        page.selectedRange = whole
    }

    /// The selection shown by the picture too, on the page it starts on, where the text is
    /// as recognized: not on a page with a fix in it, whose offsets are another text's.
    private func requestOnPage(_ range: Range<Int>?) {
        guard let range,
            let onPage = pageTexts.indices.last(where: {
                page.fixes.fixedOffset(ofPage: $0) <= range.lowerBound
            }), !page.fixes.hasFixes(onPage: onPage)
        else {
            selection.requested = nil
            return
        }
        let start = range.lowerBound - page.fixes.fixedOffset(ofPage: onPage)
        let end = range.upperBound - page.fixes.fixedOffset(ofPage: onPage)
        guard start >= 0, end <= pageTexts[onPage].count else {
            selection.requested = nil
            return
        }
        selection.requestedPage = onPage
        selection.requested = start..<end
    }

    /// The words selected go into the lookup history, off the main thread.
    private func noteLookups(_ range: Range<Int>?) {
        guard let reading = page.reading, let range else { return }
        let entries = reading.chunks(in: range).filter(\.isWord).compactMap(\.word.entries.first)
        Task.detached(priority: .utility) {
            for entry in entries { Cards.noteLookup(of: entry, from: .page) }
        }
    }

    private func keep(_ word: FoundWord, onLine line: Int, in reading: PageReading) {
        let keeper = SentenceKeeper(
            transcript: reading.text, transcriptLines: reading.lines,
            tokenLines: reading.tokenLines,
            source: nil)
        guard let store = Cards.store, let sighting = keeper.sighting(for: word, onLine: line)
        else {
            return
        }
        let kept = Cards.write {
            try store.keep(
                sighting, headword: word.cardHeadword, reading: word.cardReading,
                entryID: word.entries.first?.id, collection: Cards.currentCollectionID())
        }
        guard kept != nil else { return }
        keptWords.insert(word.wordKey)
        addedHere.insert(word.wordKey)
    }
}

/// Several chunks selected together: the phrase as it stands on the page, and, when the
/// dictionary knows it whole (an expression the tokenizer split), its entry as a word.
private struct PhraseRow: View {
    let reading: PageReading
    let chunks: [PageReading.Chunk]
    /// Puts the phrase right on the page; nil where it runs over a line break.
    let fix: ((PageFix) -> Void)?
    let kept: (FoundWord) -> Bool
    let added: (FoundWord) -> Bool
    let open: (FoundWord) -> Void
    let keep: (FoundWord) -> Void

    var body: some View {
        let phrase = chunks.map(\.surface).joined()
        let entries =
            JMdict.bundled?.entries(forAny: Deinflector.candidates(for: phrase)) ?? []
        let tokens = chunks.flatMap(\.word.tokens)
        if !entries.isEmpty, !tokens.isEmpty {
            WordReadout(
                word: FoundWord(tokens: tokens, entries: entries),
                accent: entries.first.flatMap { JMdict.bundled?.pitchAccent(of: $0) },
                estimate: entries.first.flatMap { JMdict.bundled?.estimatedPitch(of: $0) } ?? [],
                kept: kept(FoundWord(tokens: tokens, entries: entries)),
                added: added(FoundWord(tokens: tokens, entries: entries)),
                canKeep: Cards.store != nil, fix: fix,
                open: { open(FoundWord(tokens: tokens, entries: entries)) }
            ) {
                keep(FoundWord(tokens: tokens, entries: entries))
            }
        } else {
            Text(japanese: phrase)
                .font(.title3)
                .textSelection(.enabled)
            if let fix {
                FixButton(surface: phrase, fix: fix)
            }
        }
    }
}

/// A part's row, told from every other word's parts.
private struct PartRow: Identifiable {
    let id: String
    let part: FoundWord
}
