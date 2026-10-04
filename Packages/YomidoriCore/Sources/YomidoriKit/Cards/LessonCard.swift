import SwiftUI
import YomidoriCore

/// One card in a lesson, whole: the word with its pitch, its sentences, and what the
/// dictionary has around it; three buttons decide where it goes.
struct LessonCard: View {
    enum Verdict {
        case start
        case later
        case drop
    }

    let card: Card
    /// A sentence put right, here where the word is first learned.
    let correct: (Sighting) -> Void
    let decide: (Verdict) -> Void
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
        .safeAreaInset(edge: .bottom) {
            FitsOrStacks {
                Button(role: .destructive) {
                    decide(.drop)
                } label: {
                    Text("Drop", bundle: .module).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.delete, modifiers: .command)
                .help(Text("Drop the card (⌘⌫)", bundle: .module))
                Button {
                    decide(.later)
                } label: {
                    Text("Later", bundle: .module).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .help(Text("Put it back for later (⌘→)", bundle: .module))
                Button {
                    decide(.start)
                } label: {
                    Text("Start", bundle: .module).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .help(Text("Start the card (↩)", bundle: .module))
            }
            .controlSize(.large)
            .padding(16)
            .background(Palette.page)
        }
        .task(id: card.id) {
            details = await WordDetails.load(headword: card.headword, reading: card.reading)
        }
    }
}
