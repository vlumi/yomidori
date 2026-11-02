import SwiftUI
import YomidoriCore

/// Which question this is, in its own color at the top of the screen, so what to type is
/// plain at a glance: violet for the reading, rose for the meaning, amber for the pitch.
struct QuestionTag: View {
    let question: Question

    var body: some View {
        Label {
            Text(verbatim: question.name.uppercased())
                .font(.subheadline.weight(.bold))
                .tracking(1)
        } icon: {
            Image(systemName: question.symbol)
        }
        // A toolbar shows a label's icon alone unless told otherwise.
        .labelStyle(.titleAndIcon)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(question.color, in: Capsule())
        .accessibilityLabel(Text(verbatim: question.name))
    }
}

/// The question as a dot of its color with its symbol, the tag's in small: a legend's
/// key, a caption's, a card's row.
struct QuestionMark: View {
    let question: Question
    var size: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let side = size * scale
        Image(systemName: question.symbol)
            .font(.system(size: side * 0.55, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: side, height: side)
            .background(question.color, in: Circle())
            .accessibilityLabel(Text(verbatim: question.name))
    }
}
