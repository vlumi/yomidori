import SwiftUI

struct DrawerHandle: View {
    @Binding var fraction: Double
    let screenHeight: CGFloat
    /// Called when the finger lifts, for whatever lays itself out to the drawer's edge.
    let settled: () -> Void
    @GestureState private var fractionAtStart: Double?

    var body: some View {
        Capsule()
            .fill(Palette.silver)
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .updating($fractionAtStart) { _, start, _ in
                        if start == nil { start = fraction }
                    }
                    .onChanged { value in
                        let start = fractionAtStart ?? fraction
                        let range = CaptureDrawer<EmptyView, EmptyView>.fractions
                        fraction = min(
                            max(start - value.translation.height / screenHeight, range.lowerBound),
                            range.upperBound)
                    }
                    .onEnded { _ in settled() })
    }
}
