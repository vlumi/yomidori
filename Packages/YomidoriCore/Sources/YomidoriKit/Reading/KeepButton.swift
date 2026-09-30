import SwiftUI
import YomidoriCore

/// Keep; for a word with a card already, the sentence at hand added to it, and the mark that
/// opens the card; once the sentence is on it, only the mark.
struct KeepButton: View {
    /// The word has a card.
    let kept: Bool
    /// What is at hand is on the card already (or there is nothing at hand to add).
    var added = true
    let canKeep: Bool
    let keep: () -> Void
    var open: (() -> Void)?

    var body: some View {
        if kept {
            HStack(spacing: 8) {
                if !added, canKeep {
                    Button(action: keep) {
                        Label {
                            Text("Add this sentence", bundle: .module)
                        } icon: {
                            Image(systemName: "text.badge.plus")
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(Text("Add this sentence", bundle: .module))
                }
                Button {
                    open?()
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Kept; open the card", bundle: .module))
                .help(Text("Kept; open the card", bundle: .module))
                .disabled(open == nil)
            }
        } else if canKeep {
            Button(action: keep) {
                Label {
                    Text("Keep", bundle: .module)
                } icon: {
                    Image(systemName: "plus.rectangle.on.rectangle")
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(Text("Keep", bundle: .module))
        }
    }
}

/// A card over whatever screen opened it, with Done.
struct CardSheet: View {
    let card: Card
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CardView(card: card)
                .appDestinations()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done", bundle: .module)
                        }
                    }
                }
        }
    }
}
