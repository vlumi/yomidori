import SwiftUI

/// Under a still the drawer lies over the page, so its height is its own business; under
/// the camera it is only the button row.
struct CaptureDrawer<Content: View, Buttons: View>: View {
    static var fractions: ClosedRange<Double> { 0.2...0.8 }

    let hasStill: Bool
    let screenHeight: CGFloat
    @Binding var fraction: Double
    let settled: (Double) -> Void
    @ViewBuilder var content: () -> Content
    @ViewBuilder var buttons: () -> Buttons

    static func height(fraction: Double, screenHeight: CGFloat) -> CGFloat {
        max(180, screenHeight * fraction)
    }

    static func minimumHeight(screenHeight: CGFloat) -> CGFloat {
        height(fraction: fractions.lowerBound, screenHeight: screenHeight)
    }

    var body: some View {
        VStack(spacing: 12) {
            if hasStill {
                DrawerHandle(fraction: $fraction, screenHeight: screenHeight, settled: settled)
                ScrollView {
                    VStack(spacing: 12) {
                        content()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            buttons()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .frame(height: hasStill ? Self.height(fraction: fraction, screenHeight: screenHeight) : nil)
        .background(Palette.page.ignoresSafeArea(edges: .bottom))
        .tint(Palette.nightGreen)
    }
}
