import SwiftUI
import YomidoriCore

/// The tapped word, large, with its reading, its pitch when the dictionary knows it,
/// the dictionary and Keep, and the meaning under a fold.
struct WordReadout: View {
    let token: Token
    let entries: [DictionaryEntry]
    let accent: PitchAccent?
    let kept: Bool
    let canKeep: Bool
    let keep: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            WordTitle(
                headword: token.surface, reading: reading, accent: accent,
                dictionaryForm: token.dictionaryForm
            ) {
                DictionaryButton(
                    term: entries.first?.headword ?? token.dictionaryForm ?? token.surface)
                keepButton
            }
            if canKeep {
                MeaningFold { meaning }
            }
        }
    }

    /// The entry's reading under the pitch line, the tokenizer's otherwise.
    private var reading: String {
        if accent != nil, let reading = entries.first?.readings.first {
            return Kana.hiragana(reading)
        }
        return token.reading
    }

    @ViewBuilder private var keepButton: some View {
        if kept {
            Label {
                Text("Kept", bundle: .module)
            } icon: {
                Image(systemName: "checkmark")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        } else if canKeep {
            Button(action: keep) {
                Label {
                    Text("Keep", bundle: .module)
                } icon: {
                    Image(systemName: "plus.rectangle.on.rectangle")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var meaning: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entries.isEmpty {
                Text("Not in the dictionary.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(entries.prefix(3)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(entry.headword)  \(entry.readings.joined(separator: "、"))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    SensesList(entry: entry)
                }
            }
        }
        .textSelection(.enabled)
    }
}
