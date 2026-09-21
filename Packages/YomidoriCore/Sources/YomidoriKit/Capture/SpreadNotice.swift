import SwiftUI

struct SpreadNotice: View {
    let startOver: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Text("Take the next page, or start over.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(Palette.silver)
                Button {
                    startOver()
                } label: {
                    Text("Start over", bundle: .module)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .padding(.bottom, 16)
        }
    }
}
