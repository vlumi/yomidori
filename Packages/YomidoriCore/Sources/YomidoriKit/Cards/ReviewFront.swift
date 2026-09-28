import SwiftUI
import YomidoriCore

struct ReviewFront: View {
    let card: Card
    /// Opens the sentence for correction; nil where it can't be edited.
    var edit: ((Sighting) -> Void)?

    /// The sentence shown: the latest sighting's.
    static func sighting(of card: Card) -> Sighting? {
        card.sightings.max(by: { $0.date < $1.date }).flatMap { $0.sentence.isEmpty ? nil : $0 }
    }

    var body: some View {
        if let sighting = Self.sighting(of: card) {
            MarkedSentence(sighting: sighting, font: .title2)
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
