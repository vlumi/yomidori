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
    /// Where the finger landed and where the drawer stood then. Kept by the view and not as
    /// gesture state: a gesture state's updating closure does not reliably see what it set
    /// on the event before, so a start taken there slid along with the drawer, every move
    /// counted from the last one while the finger's travel kept counting from the first,
    /// and the drawer ran ahead of the finger. The finger's landing tells a new drag from
    /// the one before, should that one have been cut short without ending.
    @State private var start: (at: CGPoint, fraction: Double)?

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
                    .onChanged { value in
                        if start?.at != value.startLocation {
                            start = (value.startLocation, fraction)
                        }
                        fraction = DrawerDetents.dragged(
                            from: start?.fraction ?? fraction, by: value.translation.height,
                            screenHeight: screenHeight)
                    }
                    .onEnded { _ in
                        start = nil
                        settled(fraction)
                    }
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
