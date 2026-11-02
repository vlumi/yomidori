import SwiftUI
import YomidoriCore

/// One sighting on a card: the sentence with the word marked, and the rows that correct it
/// or take it off the card.
struct SightingSection: View {
    let sighting: Sighting
    let headword: String
    let edit: () -> Void
    let remove: () -> Void
    @State private var removing = false

    var body: some View {
        Section {
            if sighting.sentence.isEmpty {
                Text("Kept from a search; no sentence yet.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                MarkedSentence(sighting: sighting, headword: headword)
                SpeakButton(text: sighting.sentence)
            }
            Button(action: edit) {
                Label {
                    Text("Correct the sentence", bundle: .module)
                } icon: {
                    Image(systemName: "pencil")
                }
            }
            Button(role: .destructive) {
                removing = true
            } label: {
                Label {
                    Text("Remove the sentence", bundle: .module)
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .confirmationDialog(
                Text("Remove this sentence?", bundle: .module), isPresented: $removing
            ) {
                Button(role: .destructive, action: remove) {
                    Text("Remove", bundle: .module)
                }
            } message: {
                Text("The word's card stays, with its answers.", bundle: .module)
            }
        } header: {
            Text(
                verbatim: [
                    sighting.source, sighting.date.formatted(date: .abbreviated, time: .omitted),
                ].compactMap { $0 }.joined(separator: " · "))
        }
    }
}
