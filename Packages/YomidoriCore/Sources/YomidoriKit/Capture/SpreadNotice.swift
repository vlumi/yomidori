import SwiftUI

/// Over the camera while the next page of a spread is awaited: take it, go back to the
/// page already taken (the + pressed by mistake), or start the spread over.
struct SpreadNotice: View {
    let backToPage: () -> Void
    let startOver: () -> Void

    var body: some View {
        VStack {
            Spacer()
            FitsOrStacks {
                Text("Take the next page.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(Palette.silver)
                Button {
                    backToPage()
                } label: {
                    Text("Back to the page", bundle: .module)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
