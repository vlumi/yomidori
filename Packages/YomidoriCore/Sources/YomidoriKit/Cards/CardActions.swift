import SwiftUI
import YomidoriCore

/// Where the card stands, and the moves between the stacks: a lesson's Start by hand,
/// back to waiting, or shelved for the record only.
struct CardActions: View {
    @Binding var card: Card
    let save: () -> Void
    @State private var forgetting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Section {
            if card.isWaiting {
                Button {
                    card.start(at: Date())
                    save()
                } label: {
                    Label {
                        Text("Start now", bundle: .module)
                    } icon: {
                        Image(systemName: "play")
                    }
                }
            }
            if card.isInReview {
                Button {
                    card.sendToWaiting()
                    save()
                } label: {
                    Label {
                        Text("Send back to waiting", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                }
            }
            if card.shelved {
                Button {
                    card.sendToWaiting()
                    save()
                } label: {
                    Label {
                        Text("Take off the shelf", bundle: .module)
                    } icon: {
                        Image(systemName: "tray.and.arrow.up")
                    }
                }
            } else {
                Button {
                    card.shelve()
                    save()
                } label: {
                    Label {
                        Text("Shelve, never review", bundle: .module)
                    } icon: {
                        Image(systemName: "tray.and.arrow.down")
                    }
                }
            }
            // The card gone for good, from here as from the list's swipe, since a card open
            // beside its list has no row to swipe.
            Button(role: .destructive) {
                forgetting = true
            } label: {
                Label {
                    Text("Forget this card", bundle: .module)
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .help(Text("Forget the card (⌘⌫)", bundle: .module))
            .confirmationDialog(
                Text("Forget this card?", bundle: .module), isPresented: $forgetting
            ) {
                Button(role: .destructive) {
                    Cards.write { try Cards.store?.remove(card) }
                    dismiss()
                } label: {
                    Text("Forget", bundle: .module)
                }
            } message: {
                Text("Its sentences and its answers go with it.", bundle: .module)
            }
        } header: {
            if card.shelved {
                Text("Shelved", bundle: .module)
            } else if card.isWaiting {
                Text("Waiting for a lesson", bundle: .module)
            } else {
                Text("In review", bundle: .module)
            }
        }
    }
}
