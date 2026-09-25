import SwiftUI

/// A round button over the page, for the few things done to the page itself.
struct PageButton: View {
    let symbol: String
    let label: Text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .turnsWithPhone()
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.55), in: Circle())
                .foregroundStyle(.white)
        }
        .accessibilityLabel(label)
    }
}
