import SwiftUI
import YomidoriCore

/// A card's line in the list: the word, its reading in green, its rank at the end.
struct CardRow: View {
    let card: Card

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(japanese: card.headword)
                .font(.title3)
            Text(japanese: card.reading)
                .foregroundStyle(Palette.nightGreen)
            Spacer()
            RankMark(rank: card.rank, size: 22)
                .accessibilityLabel(RankName.text(for: card.rank))
        }
    }
}

/// The question before one card goes from its row's menu.
struct ForgetOneDialog: ViewModifier {
    @Binding var card: Card?
    let forgotten: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            Text("Forget this card?", bundle: .module),
            isPresented: Binding(get: { card != nil }, set: { if !$0 { card = nil } }),
            presenting: card
        ) { card in
            Button(role: .destructive) {
                Cards.write { try Cards.store?.remove(card) }
                forgotten()
            } label: {
                Text("Forget", bundle: .module)
            }
        } message: { _ in
            Text("Their sentences and their answers go with them.", bundle: .module)
        }
    }
}
