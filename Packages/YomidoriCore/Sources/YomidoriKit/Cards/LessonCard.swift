import SwiftUI
import YomidoriCore

/// One card in a lesson, whole: the word with its pitch, its sentences, and what the
/// dictionary has around it. The lesson's bar below decides where it goes.
struct LessonCard: View {
    let card: Card
    /// A sentence put right, here where the word is first learned.
    let correct: (Sighting) -> Void
    @State private var details = WordDetails()
    @State private var editing: Sighting?

    var body: some View {
        List {
            WordHeader(headword: card.headword, reading: card.reading, details: details)
            ForEach(card.sightingsNewestFirst) { sighting in
                if !sighting.sentence.isEmpty {
                    Section {
                        MarkedSentence(sighting: sighting)
                        SpeakButton(text: sighting.sentence)
                        Button {
                            editing = sighting
                        } label: {
                            Label {
                                Text("Correct the sentence", bundle: .module)
                            } icon: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                }
            }
            WordSections(headword: card.headword, details: details)
        }
        .sheet(item: $editing) { sighting in
            SentenceEditor(sighting: sighting, save: correct)
                .sheetSize(width: 520, height: 360)
        }
        .task(id: card.id) {
            details = await WordDetails.load(headword: card.headword, reading: card.reading)
        }
    }
}
