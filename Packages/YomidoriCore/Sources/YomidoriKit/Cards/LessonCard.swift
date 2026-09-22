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
                    accent: details.accent(of: card.reading), font: .largeTitle
                ) {
                    DictionaryButton(term: card.headword).labelStyle(.iconOnly)
                }
            }
            ForEach(card.sightings.sorted { $0.date > $1.date }) { sighting in
                if !sighting.sentence.isEmpty {
                    Section {
                        MarkedSentence(sighting: sighting)
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
                Button {
                    decide(.later)
                } label: {
                    Text("Later", bundle: .module).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    decide(.start)
                } label: {
                    Text("Start", bundle: .module).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
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
