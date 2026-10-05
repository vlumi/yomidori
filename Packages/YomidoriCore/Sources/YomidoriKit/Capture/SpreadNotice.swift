import SwiftUI

/// Over the camera while the next page of a spread is awaited: a Cancel at the top, where
/// one is looked for, that brings the page already taken back (the + pressed by mistake);
/// Start over beside it; and what to do, said once at the bottom.
struct SpreadNotice: View {
    let backToPage: () -> Void
    let startOver: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button {
                    backToPage()
                } label: {
                    Label {
                        Text("Cancel", bundle: .module)
                    } icon: {
                        Image(systemName: "xmark")
                    }
                }
                .help(Text("Back to the page already taken", bundle: .module))
                Spacer()
                Button {
                    startOver()
                } label: {
                    Label {
                        Text("Start over", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .padding(12)
            Spacer()
            Text("Take the next page.", bundle: .module)
                .font(.callout)
                .foregroundStyle(Palette.silver)
                .padding(10)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .padding(.bottom, 16)
        }
    }
}
