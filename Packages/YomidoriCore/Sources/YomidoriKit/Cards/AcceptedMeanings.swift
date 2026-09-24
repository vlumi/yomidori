import SwiftUI
import YomidoriCore

/// The meanings the reader added to a card, each removable, and a field for another.
struct AcceptedMeanings: View {
    @Binding var card: Card
    let save: () -> Void
    @State private var draft = ""

    var body: some View {
        Section {
            // By place: meanings merged from another device may repeat one.
            ForEach(Array(card.acceptedMeanings.enumerated()), id: \.offset) { _, meaning in
                Text(verbatim: meaning)
            }
            .onDelete { offsets in
                card.acceptedMeanings.remove(atOffsets: offsets)
                save()
            }
            TextField(text: $draft) {
                Text("Another meaning to accept", bundle: .module)
            }
            .onSubmit {
                let meaning = draft.trimmingCharacters(in: .whitespaces)
                draft = ""
                guard !meaning.isEmpty, !card.acceptedMeanings.contains(meaning) else { return }
                card.acceptedMeanings.append(meaning)
                save()
            }
        } header: {
            Text("Your meanings", bundle: .module)
        }
    }
}
