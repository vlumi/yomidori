import SwiftUI
import YomidoriCore

/// Review and the lesson as two fat buttons side by side, each in its own color, so what
/// there is to do stands out; gray when nothing is due or waiting. The buttons themselves
/// are the caller's — a link on the Study tab, a button that switches to it on Home — in
/// `FatButtonStyle`, with these labels.
enum StudyButtons {
    static func review(due: Int) -> some View {
        FatLabel(
            title: Text("Review", bundle: .module), number: due,
            noun: Text("due", bundle: .module), none: Text("Nothing due", bundle: .module),
            symbol: "checkmark.rectangle.stack")
    }

    static func lesson(waiting: Int) -> some View {
        FatLabel(
            title: Text("Lesson", bundle: .module), number: waiting,
            noun: Text("waiting", bundle: .module), none: Text("None waiting", bundle: .module),
            symbol: "book")
    }

    static let reviewColor = Palette.nightGreen
    /// The sky's blue of the flying rank: a lesson is where a card takes off.
    static let lessonColor = Rank.flying.color
}

/// The symbol over the name over the count, centered, filling the button: the number big,
/// since it is what the button is for, its noun small beside it.
private struct FatLabel: View {
    let title: Text
    let number: Int
    let noun: Text
    let none: Text
    let symbol: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.title2)
                .padding(.bottom, 2)
            title
                .font(.headline)
            if number > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: "\(number)")
                        .font(.title.weight(.bold).monospacedDigit())
                    noun
                        .font(.subheadline)
                        .opacity(0.85)
                }
                .accessibilityElement(children: .combine)
            } else {
                none
                    .font(.subheadline)
                    .opacity(0.85)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A tall filled button in a color of its own, white on it; gray and quiet when disabled.
struct FatButtonStyle: ButtonStyle {
    let color: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isEnabled ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .background(
                isEnabled ? color : Color.gray.opacity(0.18),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
