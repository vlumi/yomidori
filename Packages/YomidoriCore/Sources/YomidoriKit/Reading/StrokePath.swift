import SwiftUI
import YomidoriCore

extension Path {
    /// An SVG path, scaled from KanjiVG's box to `side` points.
    init(stroke: KanjiStroke, side: CGFloat) {
        let scale = side / KanjiStroke.boxSide
        var path = Path()
        for command in SVGPath.commands(stroke.path) {
            switch command {
            case .move(let point): path.move(to: point)
            case .line(let point): path.addLine(to: point)
            case .curve(let end, let c1, let c2): path.addCurve(to: end, control1: c1, control2: c2)
            case .quad(let end, let control): path.addQuadCurve(to: end, control: control)
            case .close: path.closeSubpath()
            }
        }
        self = path.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
}
