import SwiftUI
import YomidoriCore

/// Which question this is, in its own color at the top of the screen, so what to type is
/// plain at a glance: green for the reading, blue for the meaning, amber for the pitch.
struct QuestionTag: View {
    let question: Question

    var body: some View {
        Label {
            Text(verbatim: question.name.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
        } icon: {
            Image(systemName: symbol)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(question.color, in: Capsule())
        .accessibilityLabel(Text(verbatim: question.name))
    }

    private var symbol: String {
        switch question {
        case .reading: return "character.ja"
        case .meaning: return "text.book.closed"
        case .pitch: return "waveform"
        }
    }
}
