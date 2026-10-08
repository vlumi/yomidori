import SwiftUI
import YomidoriCore

/// Under a still the drawer lies over the page, so its height is its own business; under
/// the camera it is only the button row. On the handle's row, at the drawer's edge, stand
/// the page's two buttons: `near` at the side the thumb holds, `far` at the other.
struct CaptureDrawer<Content: View, Buttons: View, Near: View, Far: View>: View {
    let hasStill: Bool
    let screenHeight: CGFloat
    /// The tab bar's height under the drawer, which the words run under: the last of them
    /// must still come up above it.
    let bottomInset: CGFloat
    let side: PageControlsSide
    @Binding var fraction: Double
    let settled: (Double) -> Void
    let toggled: () -> Void
    @ViewBuilder var content: () -> Content
    @ViewBuilder var buttons: () -> Buttons
    @ViewBuilder var near: () -> Near
    @ViewBuilder var far: () -> Far

    var body: some View {
        VStack(spacing: 12) {
            if hasStill {
                DrawerHandle(
                    fraction: $fraction, screenHeight: screenHeight, settled: settled,
                    toggled: toggled
                )
                .frame(minHeight: 44)
                .overlay(alignment: side == .left ? .leading : .trailing) {
                    near().padding(.horizontal, 12)
                }
                .overlay(alignment: side == .left ? .trailing : .leading) {
                    far().padding(.horizontal, 12)
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        // Lazy for its pinned section headers: the recognized text's title
                        // stays at the top while its lines scroll.
                        LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                            content()
                        }
                        .id(TabTop.id)
                    }
                    .scrollsToTopOnReselect(of: .read, with: proxy)
                    // Under the tab bar, as a list's rows go: seen through the glass, and
                    // there when the bar folds to its one icon on a scroll — a drawer that
                    // stopped at the bar's edge left a bare band of its own color there.
                    .ignoresSafeArea(edges: .bottom)
                    // The bar's height as a margin, or the last rows could be seen only
                    // while a finger held them up from under it.
                    .contentMargins(.bottom, 12 + bottomInset, for: .scrollContent)
                }
                .frame(maxWidth: .infinity)
            }
            buttons()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, hasStill ? 0 : 12)
        .frame(maxWidth: .infinity)
        .frame(
            height: hasStill
                ? DrawerDetents.height(fraction: fraction, screenHeight: screenHeight) : nil
        )
        .background(Palette.page.ignoresSafeArea(edges: .bottom))
        .tint(Palette.nightGreen)
    }
}
