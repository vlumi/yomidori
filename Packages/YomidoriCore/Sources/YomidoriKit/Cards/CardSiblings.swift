import SwiftUI
import YomidoriCore

/// The cards for the same word under its other readings, each with a merge: this card's
/// sightings, answers, meanings and collections join the other, and this card goes.
struct CardSiblings: View {
    let card: Card
    @State private var siblings: [Card] = []
    @State private var merging: Card?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if !siblings.isEmpty {
            Section {
                ForEach(siblings) { sibling in
                    Button {
                        merging = sibling
                    } label: {
                        Label {
                            Text(
                                "Merge into \(sibling.headword) \(sibling.reading)", bundle: .module
                            )
                        } icon: {
                            Image(systemName: "arrow.triangle.merge")
                        }
                    }
                }
            } header: {
                Text("Also read", bundle: .module)
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "The same word under another reading. Merged, this card's sentences and answers join the other and this one goes.",
                    bundle: .module)
            }
            .confirmationDialog(
                Text("Merge into the other card?", bundle: .module),
                isPresented: Binding(get: { merging != nil }, set: { if !$0 { merging = nil } }),
                presenting: merging
            ) { sibling in
                Button {
                    merge(into: sibling)
                } label: {
                    Text("Merge into \(sibling.headword) \(sibling.reading)", bundle: .module)
                }
            }
        }
        Color.clear.frame(height: 0).listRowBackground(Color.clear)
            .task(id: card.id) { siblings = Cards.siblings(of: card) }
    }

    private func merge(into sibling: Card) {
        guard let current = Cards.store?.card(id: card.id),
            let target = Cards.store?.card(id: sibling.id)
        else { return }
        Cards.write {
            try Cards.store?.update(target.merged(with: current))
            try Cards.store?.remove(current)
        }
        dismiss()
    }
}
