import SwiftUI
import YomidoriCore

/// Under a still the drawer lies over the page, so its height is its own business; under
/// the camera it is only the button row.
struct CaptureDrawer<Content: View, Buttons: View>: View {
    let hasStill: Bool
    let screenHeight: CGFloat
    @Binding var fraction: Double
    let settled: (Double) -> Void
    let toggled: () -> Void
    @ViewBuilder var content: () -> Content
    @ViewBuilder var buttons: () -> Buttons

    var body: some View {
        VStack(spacing: 12) {
            if hasStill {
                DrawerHandle(
                    fraction: $fraction, screenHeight: screenHeight, settled: settled,
                    toggled: toggled)
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
                    .contentMargins(.bottom, 12, for: .scrollContent)
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
