import SwiftUI
import YomidoriCore

/// The meanings the reader added to a card, each removable, and a field for another.
/// The meanings a review takes as right: the dictionary's until the reader takes one out or
/// adds one, then the reader's own list.
struct AcceptedMeanings: View {
    @Binding var card: Card
    let glosses: [String]
    let save: () -> Void
    @State private var draft = ""

    var body: some View {
        let answers = card.answers(glosses: glosses)
        Section {
            // By place: meanings merged from another device may repeat one.
            ForEach(Array(answers.enumerated()), id: \.offset) { _, meaning in
                Text(verbatim: meaning)
            }
            .onDelete { offsets in
                for meaning in offsets.map({ answers[$0] }) {
                    card.removeAnswer(meaning, glosses: glosses)
                }
                save()
            }
            TextField(text: $draft) {
                Text("Another meaning to accept", bundle: .module)
            }
            .onSubmit {
                let meaning = draft.trimmingCharacters(in: .whitespaces)
                draft = ""
                guard !meaning.isEmpty, !answers.contains(meaning) else { return }
                card.addAnswer(meaning, glosses: glosses)
                save()
            }
        } header: {
            Text("Meanings that count", bundle: .module)
        } footer: {
            if card.acceptedMeanings.isEmpty {
                Text("The dictionary's, until you change them.", bundle: .module)
            }
        }
    }
}
