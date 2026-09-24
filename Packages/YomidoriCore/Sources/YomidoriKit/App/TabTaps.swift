import SwiftUI

/// A tap on the tab already showing: its stack pops to the root and its list scrolls to the
/// top, as the rest of iOS does. Nothing else, so a tap never costs a page.
@MainActor
final class TabTaps: ObservableObject {
    @Published private(set) var counts: [AppTab: Int] = [:]
    /// Taps that found the tab's stack already at its root: the ones a root screen acts on
    /// (scroll to the top, a retake), never the tap that only popped a pushed screen.
    @Published private(set) var rootCounts: [AppTab: Int] = [:]
    /// The tab showing, for a screen that acts on being switched to.
    @Published var shown: AppTab?

    func tapped(_ tab: AppTab) {
        counts[tab, default: 0] += 1
    }

    func tappedAtRoot(_ tab: AppTab) {
        rootCounts[tab, default: 0] += 1
    }
}

/// The id of a screen's top, for the scroll back to it.
enum TabTop {
    static let id = "top"
}

private struct OnTabReselect: ViewModifier {
    let tab: AppTab
    let perform: () -> Void
    @EnvironmentObject private var taps: TabTaps

    func body(content: Content) -> some View {
        content.onChange(of: taps.rootCounts[tab] ?? 0) { _, _ in perform() }
    }
}

extension View {
    func onTabReselect(_ tab: AppTab, perform: @escaping () -> Void) -> some View {
        modifier(OnTabReselect(tab: tab, perform: perform))
    }

    /// For a tab's list: scrolls to `TabTop.id` when the tab is tapped again.
    func scrollsToTopOnReselect(of tab: AppTab, with proxy: ScrollViewProxy) -> some View {
        onTabReselect(tab) {
            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(TabTop.id, anchor: .top) }
        }
    }
}

/// A tab's stack sees every tap on its tab, and passes to its root the ones that found it
/// there.
private struct OnTabTap: ViewModifier {
    let tab: AppTab
    let perform: (TabTaps) -> Void
    @EnvironmentObject private var taps: TabTaps

    func body(content: Content) -> some View {
        content.onChange(of: taps.counts[tab] ?? 0) { _, _ in perform(taps) }
    }
}

extension View {
    func onTabTap(_ tab: AppTab, perform: @escaping (TabTaps) -> Void) -> some View {
        modifier(OnTabTap(tab: tab, perform: perform))
    }
}
