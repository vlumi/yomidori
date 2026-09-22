import SwiftUI

/// Over a page of a spread: the page's number, and the way out of the spread.
struct StartOverButton: View {
    let pageCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text("Start over", bundle: .module)
            } icon: {
                Image(systemName: "xmark")
            }
            Text(verbatim: "\(pageCount)")
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.55), in: Capsule())
        .foregroundStyle(.white)
        .accessibilityLabel(Text("Page \(pageCount); start over", bundle: .module))
    }
}
