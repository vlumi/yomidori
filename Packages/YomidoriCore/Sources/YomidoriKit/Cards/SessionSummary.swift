import SwiftUI
import YomidoriCore

/// What a sitting of reviews came to, once the queue is empty: how many answered, right and
/// missed, the minutes, and each question's share.
struct SessionSummary: View {
    let session: DayTally
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Session done", bundle: .module)
                .font(.largeTitle.weight(.semibold))
            HStack(alignment: .top) {
                stat("\(session.total)", Text("Answered", bundle: .module))
                stat("\(session.rightTotal)", Text("Right", bundle: .module))
                stat("\(session.total - session.rightTotal)", Text("Again", bundle: .module))
                stat("\(session.seconds / 60)", Text("Minutes", bundle: .module))
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Question.allCases, id: \.self) { question in
                    if let asked = session.answered[question], asked > 0 {
                        HStack {
                            QuestionTag(question: question)
                            Spacer()
                            Text(verbatim: "\(session.right[question] ?? 0) / \(asked)")
                                .monospacedDigit()
                        }
                    }
                }
            }
            Spacer()
            Button(action: done) {
                Text("Done", bundle: .module).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .tint(Palette.nightGreen)
    }

    private func stat(_ value: String, _ label: Text) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(.title.weight(.semibold))
                .monospacedDigit()
            label
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
