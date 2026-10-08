import SwiftUI

/// Two columns on an iPad with room: a list in a stack of its own, a hairline, and the
/// detail beside it, as the Mac's split lays them out. Not a `NavigationSplitView`: inside
/// the floating tab bar's `TabView`, its columns took the bar's inset once too often or not
/// at all as they were hidden and shown or the iPad turned, a blank band or an overlap.
struct PadColumns<Column: View, Detail: View>: View {
    static var columnWidth: CGFloat { 360 }
    @ViewBuilder let column: () -> Column
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        HStack(spacing: 0) {
            NavigationStack { column() }
                .frame(width: Self.columnWidth)
            Divider().ignoresSafeArea()
            detail()
        }
    }
}
