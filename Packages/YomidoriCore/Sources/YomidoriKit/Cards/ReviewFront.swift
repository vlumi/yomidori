import SwiftUI
import YomidoriCore

struct ReviewFront: View {
    let card: Card

    var body: some View {
        if let sighting = card.sightings.max(by: { $0.date < $1.date }), !sighting.sentence.isEmpty
        {
            MarkedSentence(sighting: sighting, font: .title2)
            if let cropID = sighting.cropID, let image = StillArchive.load(cropID) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            if let source = sighting.source {
                Text(verbatim: source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
