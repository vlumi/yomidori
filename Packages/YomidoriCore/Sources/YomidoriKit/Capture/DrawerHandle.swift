import SwiftUI
import YomidoriCore

struct DrawerHandle: View {
    @Binding var fraction: Double
    let screenHeight: CGFloat
    /// Called with the fraction when the finger lifts: the moment to remember it and to lay
    /// the page out to the drawer's edge.
    let settled: (Double) -> Void
    /// A double tap: the drawer to its largest, or back to where it was.
    let toggled: () -> Void
    @GestureState private var fractionAtStart: Double?

    var body: some View {
        Capsule()
            .fill(Palette.silver)
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: toggled)
            .gesture(
                // Measured on the screen, not in the handle's own frame: the handle moves with
                // the drawer, and a finger's travel counted against a frame that travels with
                // it comes out short, then long, the drawer shaking under the finger.
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .updating($fractionAtStart) { _, start, _ in
                        if start == nil { start = fraction }
                    }
                    .onChanged { value in
                        fraction = DrawerDetents.dragged(
                            from: fractionAtStart ?? fraction, by: value.translation.height,
                            screenHeight: screenHeight)
                    }
                    .onEnded { _ in settled(fraction) }
            )
            .accessibilityElement()
            .accessibilityLabel(Text("Drawer", bundle: .module))
            .accessibilityValue(Text("\(Int((fraction * 100).rounded())) percent", bundle: .module))
            .accessibilityAdjustableAction { direction in
                let detents = DrawerDetents.all
                guard let index = detents.firstIndex(of: DrawerDetents.nearest(fraction)) else {
                    return
                }
                switch direction {
                case .increment: if index + 1 < detents.count { settled(detents[index + 1]) }
                case .decrement: if index > 0 { settled(detents[index - 1]) }
                @unknown default: break
                }
            }
            .accessibilityAction(named: Text("Expand or collapse", bundle: .module), toggled)
    }
}
