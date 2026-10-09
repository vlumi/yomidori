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
            detail().environment(\.inPadColumns, true)
        }
    }
}

private struct InPadColumnsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Whether the view stands in a `PadColumns` detail, where the list is beside it.
    var inPadColumns: Bool {
        get { self[InPadColumnsKey.self] }
        set { self[InPadColumnsKey.self] = newValue }
    }
}

/// A screen's title small in the bar when the screen stands in a column: large, it only
/// repeated the header right under it, flush with the column's edge. A phone keeps the
/// large title, which its header scrolls away under.
private struct ColumnTitle: ViewModifier {
    @Environment(\.inPadColumns) private var inColumns

    func body(content: Content) -> some View {
        #if os(iOS)
        content.navigationBarTitleDisplayMode(inColumns ? .inline : .automatic)
        #else
        content
        #endif
    }
}

extension View {
    func columnTitle() -> some View {
        modifier(ColumnTitle())
    }
}
