import SwiftUI

/// Side by side while it fits the width, stacked when the type size outgrows the row.
struct FitsOrStacks<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder let content: () -> Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: spacing) { content() }
            VStack(alignment: .leading, spacing: spacing / 2) { content() }
        }
    }
}
