import SwiftUI
import YomidoriCore

/// Where the card stands, and the moves between the stacks: a lesson's Start by hand,
/// back to waiting, or shelved for the record only.
struct CardActions: View {
    @Binding var card: Card
    let save: () -> Void

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
