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
            Text(verbatim: card.headword)
                .font(.largeTitle)
                .foregroundStyle(Palette.nightGreen)
        }
    }
}

struct MeaningQuestion: View {
    let card: Card

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(verbatim: card.headword)
                .font(.title)
            Text(verbatim: card.reading)
                .font(.title3)
                .foregroundStyle(Palette.nightGreen)
            Text("What does it mean?", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
