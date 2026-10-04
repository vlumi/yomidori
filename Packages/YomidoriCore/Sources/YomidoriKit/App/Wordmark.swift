import SwiftUI
import YomidoriCore

/// The name in katakana, in the app's green, at a size; and the name read as the app reads
/// any word, its kana with its pitch. 読み鳥 drops after the second mora, as 鳴き鳥 and 飼い鳥
/// do and most words of two morae and 鳥; 読み取り, which it puns on, is flat.
struct Wordmark: View {
    let size: CGFloat

    var body: some View {
        Text(japanese: "ヨミドリ")
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(Palette.nightGreen)
    }

    static var reading: some View {
        PitchReading(reading: "よみどり", accent: PitchAccent(downstep: 2))
            .accessibilityLabel(Text(japanese: "よみどり"))
    }
}

/// What the Study and Home screens offer: the review with its count, the lesson with how
/// many wait. The same words and icons on both, in whatever the screen wraps them in.
enum StudyLabel {
    static func review(_ due: Int) -> some View {
        Label {
            Text("Review \(due)", bundle: .module)
        } icon: {
            Image(systemName: "checkmark.rectangle.stack")
        }
    }

    static func lesson(waiting: Int) -> some View {
        Label {
            Text("Lesson · \(waiting) waiting", bundle: .module)
        } icon: {
            Image(systemName: "book")
        }
    }

    static var nothingDue: some View {
        Text("Nothing due. Read on.", bundle: .module)
            .foregroundStyle(.secondary)
    }
}
