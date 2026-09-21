import SwiftUI

struct ZoomButtons: View {
    static let step: CGFloat = 1.6
    let zoom: (CGFloat) -> Void

    var body: some View {
        VStack(spacing: 10) {
            button("plus.magnifyingglass", Text("Zoom in", bundle: .module), factor: Self.step)
            button(
                "minus.magnifyingglass", Text("Zoom out", bundle: .module), factor: 1 / Self.step)
        }
    }

    private func button(_ symbol: String, _ label: Text, factor: CGFloat) -> some View {
        Button {
            zoom(factor)
        } label: {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.55), in: Circle())
                .foregroundStyle(.white)
        }
        .accessibilityLabel(label)
    }
}
