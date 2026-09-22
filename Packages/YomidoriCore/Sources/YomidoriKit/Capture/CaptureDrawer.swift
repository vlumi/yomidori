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
                        VStack(spacing: 12) {
                            content()
                        }
                        .id(TabTop.id)
                    }
                    .scrollsToTopOnReselect(of: .read, with: proxy)
                }
                .frame(maxWidth: .infinity)
            }
            buttons()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .frame(
            height: hasStill
                ? DrawerDetents.height(fraction: fraction, screenHeight: screenHeight) : nil
        )
        .background(Palette.page.ignoresSafeArea(edges: .bottom))
        .tint(Palette.nightGreen)
    }
}
