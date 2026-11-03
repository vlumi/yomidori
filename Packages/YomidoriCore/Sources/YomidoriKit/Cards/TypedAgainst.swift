import SwiftUI
import YomidoriCore

/// What was typed over what the answer is, a slip marked where it is: the kana typed that
/// should not have been struck through in red, the kana of the answer that were not typed
/// underlined in green, the rest plain, so a typo reads as one wrong kana and a wrong
/// reading as a different word.
struct TypedAgainst: View {
    let typed: String
    let answer: String

    var body: some View {
        let parts = AnswerDiff.of(typed: typed, answer: answer)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                typedLine(parts)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Palette.nightGreen)
                    .accessibilityHidden(true)
                answerLine(parts)
            }
        }
        .font(.title3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Not quite. You typed \(typed).", bundle: .module))
    }

    // One attributed string per line rather than Texts joined with `+`, which iOS 26 and
    // macOS 26 deprecate.
    private func typedLine(_ parts: [AnswerDiff.Part]) -> Text {
        var line = AttributedString()
        for part in parts {
            switch part {
            case .same(let text): line += AttributedString(text)
            case .extra(let text):
                var extra = AttributedString(text)
                extra.foregroundColor = Color.red
                extra.inlinePresentationIntent = .stronglyEmphasized
                extra.strikethroughStyle = .single
                line += extra
            case .missing: break
            }
        }
        return Text(line)
    }

    private func answerLine(_ parts: [AnswerDiff.Part]) -> Text {
        var line = AttributedString()
        for part in parts {
            switch part {
            case .same(let text): line += AttributedString(text)
            case .missing(let text):
                var missing = AttributedString(text)
                missing.foregroundColor = Palette.nightGreen
                missing.inlinePresentationIntent = .stronglyEmphasized
                missing.underlineStyle = .single
                line += missing
            case .extra: break
            }
        }
        return Text(line)
    }
}
