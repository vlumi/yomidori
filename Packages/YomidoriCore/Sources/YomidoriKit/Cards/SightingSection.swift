import SwiftUI
import YomidoriCore

/// One sighting on a card: the sentence with the word marked, and the row that corrects it.
struct SightingSection: View {
    let sighting: Sighting
    let edit: () -> Void

    var body: some View {
        Section {
            if sighting.sentence.isEmpty {
                Text("Kept from a search; no sentence yet.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                MarkedSentence(sighting: sighting)
            }
            Button(action: edit) {
                Label {
                    Text("Correct the sentence", bundle: .module)
                } icon: {
                    Image(systemName: "pencil")
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
