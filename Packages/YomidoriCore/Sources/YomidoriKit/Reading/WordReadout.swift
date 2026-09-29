import SwiftUI
import YomidoriCore

/// One found word as a row: the title and Keep, and under the row, opened by a tap anywhere
/// along it, the meaning, the system dictionary and the way to the full entry.
struct WordReadout: View {
    let word: FoundWord
    let accent: PitchAccent?
    /// The pitch as worked out, for a word without an accent of the dictionary's.
    var estimate: [PitchPhrase] = []
    let kept: Bool
    /// This sentence is on the card already.
    var added = true
    let canKeep: Bool
    /// Puts the word right on the page; nil where the word has no place in the page's text
    /// to put it right in.
    var fix: ((PageFix) -> Void)?
    /// Shows the card the word is kept on.
    var open: (() -> Void)?
    let keep: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                WordTitle(
                    headword: word.surface, reading: reading, accent: accent,
                    estimate: estimate, dictionaryForm: word.dictionaryForm
                ) {
                    keepButton
                }
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .accessibilityRemoveTraits(.isImage)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(
                        expanded
                            ? Text("Hide the meaning", bundle: .module)
                            : Text("Show the meaning", bundle: .module)
                    )
                    .accessibilityAction { toggle() }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: toggle)
            if expanded {
                meaning
            }
        }
    }

    private func toggle() {
        withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
    }

    private var headword: String {
        word.dictionaryForm ?? word.surface
    }

    private var reading: String {
        if accent != nil, let reading = word.entries.first?.readings.first {
            return Kana.hiragana(reading)
        }
        return word.reading
    }

    private var keepButton: some View {
        KeepButton(kept: kept, added: added, canKeep: canKeep, keep: keep, open: open)
    }

    private var meaning: some View {
        VStack(alignment: .leading, spacing: 6) {
            if word.entries.isEmpty {
                Text("Not in the dictionary.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(word.entries.prefix(3)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(entry.headword)  \(entry.readings.joined(separator: "、"))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    SensesList(entry: entry)
                }
            }
            HStack(spacing: 12) {
                if let fix {
                    FixButton(surface: word.surface, fix: fix)
                }
                DictionaryButton(term: word.entries.first?.headword ?? headword)
                if let entry = word.entries.first {
                    NavigationLink(value: entry) {
                        Label {
                            Text("Full entry", bundle: .module)
                        } icon: {
                            Image(systemName: "text.book.closed")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.top, 4)
        }
        .padding(.leading, 4)
        .textSelection(.enabled)
    }
}
