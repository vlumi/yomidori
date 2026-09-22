import SwiftUI
import YomidoriCore

/// One sighting on a card: the sentence with the word marked, its photos, and the rows
/// that correct the sentence or drop the photos.
struct SightingSection: View {
    let sighting: Sighting
    let edit: () -> Void
    let removeImages: () -> Void

    var body: some View {
        Section {
            if sighting.sentence.isEmpty {
                Text("Kept from a search; no sentence yet.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                MarkedSentence(sighting: sighting)
            }
            let images = [sighting.cropID].compactMap { $0 } + sighting.stillIDs
            ForEach(images, id: \.self) { id in
                if let image = StillArchive.load(id) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            Button(action: edit) {
                Label {
                    Text("Correct the sentence", bundle: .module)
                } icon: {
                    Image(systemName: "pencil")
                }
            }
            if sighting.hasImages {
                Button(role: .destructive, action: removeImages) {
                    Label {
                        Text("Remove the photos", bundle: .module)
                    } icon: {
                        Image(systemName: "photo.badge.minus")
                    }
                }
            }
        } header: {
            Text(
                verbatim: [
                    sighting.source, sighting.date.formatted(date: .abbreviated, time: .omitted),
                ].compactMap { $0 }.joined(separator: " · "))
        }
    }
}
