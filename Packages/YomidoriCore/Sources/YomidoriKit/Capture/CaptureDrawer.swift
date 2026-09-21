import SwiftUI

struct CaptureDrawer<Content: View, Buttons: View>: View {
    let hasStill: Bool
    let screenHeight: CGFloat
    @Binding var fraction: Double
    @ViewBuilder var content: () -> Content
    @ViewBuilder var buttons: () -> Buttons

    var body: some View {
        VStack(spacing: 12) {
            if hasStill {
                DrawerHandle(fraction: $fraction, screenHeight: screenHeight)
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
        .frame(height: hasStill ? max(180, screenHeight * fraction) : nil)
        .background(Palette.page)
        .tint(Palette.nightGreen)
    }
}
