import SwiftUI
import YomidoriCore

/// The question's sentence, one of the card's picked for this question, with the word marked;
/// where the sentence has the word in another form than the card's (頼みたい for 頼む), the
/// card's form under it, since that is what is asked.
struct ReviewFront: View {
    let card: Card
    /// The sighting picked for this question; the latest if it is gone.
    var sightingID: UUID?
    /// Show the card's own form when the sentence has another.
    var showsForm = false
    /// Opens the sentence for correction; nil where it can't be edited.
    var edit: ((Sighting) -> Void)?

    /// The sightings with a sentence to show.
    static func sentences(of card: Card) -> [Sighting] {
        card.sightings.filter { !$0.sentence.isEmpty }
    }

    private var sighting: Sighting? {
        let sentences = Self.sentences(of: card)
        return sentences.first { $0.id == sightingID } ?? sentences.max { $0.date < $1.date }
    }

    var body: some View {
        if let sighting {
            MarkedSentence(sighting: sighting, font: .title2)
            if showsForm, sighting.surface != card.headword {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(japanese: card.headword)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Palette.nightGreen)
                    Text("The word as the dictionary has it", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                if let source = sighting.source {
                    Text(verbatim: source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let edit {
                    Button {
                        edit(sighting)
                    } label: {
                        Label {
                            Text("Edit the sentence", bundle: .module)
                        } icon: {
                            Image(systemName: "pencil")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        } else {
            Text(japanese: card.headword)
                .font(.largeTitle)
                .foregroundStyle(Palette.nightGreen)
        }
    }
}

struct PitchQuestion: View {
    let card: Card

    var body: some View {
        FitsOrStacks {
            Text(japanese: card.headword)
                .font(.title)
            Text(japanese: card.reading)
                .font(.title3)
                .foregroundStyle(Palette.nightGreen)
            Text("Which pitch?", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct MeaningQuestion: View {
    let card: Card

    var body: some View {
        FitsOrStacks {
            Text(japanese: card.headword)
                .font(.title)
            Text(japanese: card.reading)
                .font(.title3)
                .foregroundStyle(Palette.nightGreen)
            Text("What does it mean?", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
