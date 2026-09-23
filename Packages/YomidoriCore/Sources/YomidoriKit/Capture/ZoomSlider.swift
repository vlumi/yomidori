import SwiftUI
import YomidoriCore

/// Zoom as a vertical slider over the page, up for closer, so the thumb slides it in one
/// stroke instead of tapping buttons.
struct ZoomSlider: View {
    @Binding var fraction: Double
    @ScaledMetric(relativeTo: .body) private var length: CGFloat = 170
    @State private var fractionAtStart: Double?
    private let knob: CGFloat = 30

    var body: some View {
        GeometryReader { geometry in
            let travel = max(geometry.size.height - knob, 1)
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(.black.opacity(0.45))
                    .frame(width: 8)
                    .frame(maxHeight: .infinity)
                Capsule()
                    .fill(Palette.nightGreen)
                    .frame(width: 8, height: knob / 2 + travel * fraction)
                Circle()
                    .fill(.white)
                    .shadow(radius: 2)
                    .frame(width: knob, height: knob)
                    .overlay(
                        Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.black)
                    )
                    .offset(y: -travel * fraction)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let start = fractionAtStart ?? fraction
                        if fractionAtStart == nil { fractionAtStart = start }
                        fraction = min(max(start - value.translation.height / travel, 0), 1)
                    }
                    .onEnded { _ in fractionAtStart = nil })
        }
        .frame(width: 44, height: length)
        .accessibilityElement()
        .accessibilityLabel(Text("Zoom", bundle: .module))
        .accessibilityValue(Text("\(Int((fraction * 100).rounded())) percent", bundle: .module))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: fraction = min(fraction + 0.1, 1)
            case .decrement: fraction = max(fraction - 0.1, 0)
            @unknown default: break
            }
        }
    }
}
