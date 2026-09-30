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
    let decide: (Verdict) -> Void
    @State private var details = WordDetails()

    var body: some View {
        List {
            Section {
                WordTitle(
                    headword: card.headword, reading: card.reading,
                    accent: details.accent(of: card.reading), estimate: details.estimate,
                    font: .largeTitle
                ) {
                    DictionaryButton(term: card.headword).labelStyle(.iconOnly)
                        .help(Text("Dictionary", bundle: .module))
                }
            }
            ForEach(card.sightings.sorted { $0.date > $1.date }) { sighting in
                if !sighting.sentence.isEmpty {
                    Section {
                        MarkedSentence(sighting: sighting)
                        SpeakButton(text: sighting.sentence)
                    }
                }
            }
            WordSections(headword: card.headword, details: details)
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
