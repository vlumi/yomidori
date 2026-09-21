import SwiftUI

/// Between a fifth and four fifths of the screen; the fraction is the caller's to remember.
struct DrawerHandle: View {
    @Binding var fraction: Double
    let screenHeight: CGFloat
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
                        fraction = min(
                            max(start - value.translation.height / screenHeight, 0.2), 0.8)
                    })
    }
}
