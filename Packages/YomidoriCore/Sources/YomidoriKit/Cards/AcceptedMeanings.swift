import SwiftUI
import YomidoriCore

/// The meanings the reader added to a card, each removable by a swipe or its menu, and a
/// field for another.
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
                    // The last one stays: a meaning question needs an answer.
                    .deleteDisabled(answers.count == 1)
                    .contextMenu {
                        Button(role: .destructive) {
                            remove([meaning])
                        } label: {
                            Label {
                                Text("Remove this meaning", bundle: .module)
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                        .disabled(answers.count == 1)
                    }
            }
            .onDelete { offsets in
                remove(offsets.map { answers[$0] })
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

    private func remove(_ meanings: [String]) {
        for meaning in meanings {
            card.removeAnswer(meaning, glosses: glosses)
        }
        save()
    }
}
