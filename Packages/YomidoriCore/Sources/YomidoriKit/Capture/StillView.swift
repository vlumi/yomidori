import SwiftUI
import YomidoriCore

/// The tap is reported in the still's own coordinates with the frame it occupies, whatever
/// the zoom.
struct StillView: View {
    @Binding var zoom: Zoom
    let still: Still
    let lines: [RecognizedLine]
    let selected: Set<Int>
    let highlights: [CGRect]
    let onTap: (CGPoint, CGRect) -> Void
    var onLongPress: ((CGPoint, CGRect) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let frame = TextGeometry.fittedFrame(of: still.size, in: geometry.size)
            ZStack(alignment: .topLeading) {
                Image(decorative: still.image, scale: 1)
                    .resizable()
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                ForEach(lines.indices, id: \.self) { index in
                    let rect = TextGeometry.viewRect(for: lines[index].box, in: frame)
                    let isSelected = selected.contains(index)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Palette.nightGreen.opacity(isSelected ? 0.35 : 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Palette.nightGreen, lineWidth: isSelected ? 2 : 1)
                        )
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                        .accessibilityElement()
                        .accessibilityLabel(Text(japanese: lines[index].text))
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { onTap(CGPoint(x: rect.midX, y: rect.midY), frame) }
                }
                ForEach(highlights.indices, id: \.self) { index in
                    let rect = TextGeometry.viewRect(for: highlights[index], in: frame)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Palette.nightGreen, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2).onEnded { _ in zoom = Zoom() }
                    .exclusively(before: SpatialTapGesture().onEnded { onTap($0.location, frame) })
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        if case .second(true, let drag?) = value {
                            onLongPress?(drag.location, frame)
                        }
                    },
                including: onLongPress == nil ? .none : .all
            )
            .zoomable($zoom, in: geometry.size)
            .accessibilityAction(named: Text("Reset zoom", bundle: .module)) { zoom = Zoom() }
            .clipped()
        }
    }
}
