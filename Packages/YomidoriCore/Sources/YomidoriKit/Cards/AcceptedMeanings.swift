import SwiftUI
import YomidoriCore

/// The meanings the reader added to a card, each removable, and a field for another.
struct AcceptedMeanings: View {
    @Binding var card: Card
    let save: () -> Void
    @State private var draft = ""

    var body: some View {
        Section {
            ForEach(card.acceptedMeanings, id: \.self) { meaning in
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
                guard !meaning.isEmpty else { return }
                card.acceptedMeanings.append(meaning)
                draft = ""
                save()
            }
        } header: {
            Text("Your meanings", bundle: .module)
        }
    }
}
