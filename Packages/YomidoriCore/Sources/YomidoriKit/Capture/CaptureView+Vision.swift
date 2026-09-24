import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The tap in Vision mode: the character under the finger, the word over it outlined and
/// handed to the drawer as a selection.
extension CaptureView {
    /// The line lights up and the drawer shows a spinner at once; the lookup follows a frame
    /// later, and no other tap is taken until it is done.
    func tapWord(at point: CGPoint, in frame: CGRect) {
        guard !selection.looking else { return }
        let page = VisionPage(lines: lines)
        guard let hit = page.character(at: point, in: frame) else {
            clearWord()
            return
        }
        let line = page.lines[hit.line]
        selected = lines.firstIndex(of: line)
        self.page.wordBox = nil
        selection.looking = true
        let tokenizer = tokenizerChoice.tokenizer
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            let tokens = tokenizer?.tokens(in: line.text) ?? []
            guard
                let found = WordFinder.word(
                    atCharacter: hit.character, in: tokens, text: line.text,
                    dictionary: JMdict.bundled)
            else {
                selection.looking = false
                return
            }
            self.page.wordBox = line.box(ofCharacters: found.range)
            let transcript = page.transcript
            let start = transcript.index(
                transcript.startIndex, offsetBy: page.starts[hit.line] + found.range.lowerBound)
            let range = start..<transcript.index(start, offsetBy: found.range.count)
            // The same word again: the readout has it already and will not look again.
            if selection.text == found.word.surface, selection.range == range {
                selection.looking = false
            }
            selection.range = range
            selection.text = found.word.surface
        }
    }

    func clearWord() {
        guard !selection.looking else { return }
        page.wordBox = nil
        selected = nil
        selection.text = ""
        selection.range = nil
    }
}
