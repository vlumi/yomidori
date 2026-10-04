import SwiftUI
import YomidoriCore

/// What is done to the cards picked in the list, together: put in a collection, taken out
/// of one, or forgotten, after asking. Each is one write, so one change goes to the other
/// devices.
struct CardsBatch: View {
    @Binding var picked: Set<UUID>
    let cards: [Card]
    let collections: [Collection]
    @State private var forgetting = false

    /// The collections some picked card is in: the ones there is something to take out of.
    private var holding: [Collection] {
        let held = Set(cards.filter { picked.contains($0.id) }.flatMap(\.collectionIDs))
        return collections.filter { held.contains($0.id) }
    }

    var body: some View {
        // One row: the count, and the two things to do, their names shown where they fit.
        ViewThatFits(in: .horizontal) {
            row(labels: true)
            row(labels: false)
        }
        .buttonStyle(.bordered)
        .tint(Palette.nightGreen)
        .forgetCardsDialog(isPresented: $forgetting, picked: $picked, cards: cards)
    }

    private func row(labels: Bool) -> some View {
        HStack(spacing: 10) {
            Text("\(picked.count) selected", bundle: .module)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 0)
            Menu {
                ForEach(collections) { collection in
                    Button {
                        Cards.write { try Cards.store?.add(picked, to: collection.id) }
                    } label: {
                        Text(verbatim: collection.name)
                    }
                }
            } label: {
                label(Text("Add to…", bundle: .module), "folder.badge.plus", shown: labels)
            }
            .disabled(picked.isEmpty || collections.isEmpty)
            .accessibilityLabel(Text("Add to a collection", bundle: .module))
            .help(Text("Add to a collection", bundle: .module))
            Menu {
                ForEach(holding) { collection in
                    Button(role: .destructive) {
                        Cards.write { try Cards.store?.remove(picked, from: collection.id) }
                    } label: {
                        Text(verbatim: collection.name)
                    }
                }
            } label: {
                label(Text("Take out of…", bundle: .module), "folder.badge.minus", shown: labels)
            }
            .disabled(holding.isEmpty)
            .accessibilityLabel(Text("Take out of a collection", bundle: .module))
            .help(Text("Take out of a collection", bundle: .module))
            Button(role: .destructive) {
                forgetting = true
            } label: {
                label(Text("Forget…", bundle: .module), "trash", shown: labels)
            }
            // Red, over the row's green: the one thing here that cannot be undone.
            .tint(.red)
            .disabled(picked.isEmpty)
            .accessibilityLabel(Text("Forget the cards", bundle: .module))
            .help(Text("Forget the cards", bundle: .module))
        }
    }

    @ViewBuilder private func label(_ title: Text, _ symbol: String, shown: Bool) -> some View {
        if shown {
            Label {
                title.lineLimit(1).fixedSize()
            } icon: {
                Image(systemName: symbol)
            }
        } else {
            Image(systemName: symbol)
        }
    }
}

extension View {
    /// The question before the picked cards go, with their number; forgetting them empties
    /// the pick. The Mac's ⌫ and the batch's button ask the same.
    func forgetCardsDialog(isPresented: Binding<Bool>, picked: Binding<Set<UUID>>, cards: [Card])
        -> some View
    {
        confirmationDialog(
            picked.wrappedValue.count == 1
                ? Text("Forget this card?", bundle: .module)
                : Text("Forget \(picked.wrappedValue.count) cards?", bundle: .module),
            isPresented: isPresented
        ) {
            Button(role: .destructive) {
                for card in cards where picked.wrappedValue.contains(card.id) {
                    Cards.write { try Cards.store?.remove(card) }
                }
                picked.wrappedValue = []
            } label: {
                Text("Forget", bundle: .module)
            }
        } message: {
            Text("Their sentences and their answers go with them.", bundle: .module)
        }
    }
}
