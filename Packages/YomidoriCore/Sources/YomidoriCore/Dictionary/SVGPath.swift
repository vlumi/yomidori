import Foundation

/// The subset of SVG path data KanjiVG writes (moves, lines, cubic and quadratic curves,
/// their shorthands, closes), read into absolute commands.
public enum SVGPath {
    public enum Command: Equatable, Sendable {
        case move(CGPoint)
        case line(CGPoint)
        case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
        case quad(to: CGPoint, control: CGPoint)
        case close
    }

    public static func commands(_ data: String) -> [Command] {
        var parser = Parser(tokens: tokens(of: data))
        return parser.run()
    }

    private static let token = try? NSRegularExpression(
        pattern: "[MmLlHhVvCcSsQqTtZz]|-?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE]-?\\d+)?")

    private static func tokens(of data: String) -> [String] {
        guard let token else { return [] }
        let range = NSRange(data.startIndex..., in: data)
        return token.matches(in: data, range: range).compactMap {
            Range($0.range, in: data).map { String(data[$0]) }
        }
    }

    private struct Parser {
        let tokens: [String]
        var index = 0
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint?
        var commands: [Command] = []

        mutating func run() -> [Command] {
            var letter: Character = "M"
            while index < tokens.count {
                if let first = tokens[index].first, first.isLetter {
                    letter = first
                    index += 1
                }
                let before = index
                guard apply(letter) else { break }
                // Z takes no numbers, so a number after it is garbage that would spin the loop.
                if index == before, index < tokens.count, tokens[index].first?.isLetter != true {
                    break
                }
                // A run of numbers after M continues as L, as the standard says.
                if letter == "M" { letter = "L" }
                if letter == "m" { letter = "l" }
            }
            return commands
        }

        private mutating func apply(_ letter: Character) -> Bool {
            let relative = letter.isLowercase
            let kind = Character(letter.uppercased())
            let applied: Bool
            switch kind {
            case "M", "L": applied = applyPoint(kind, relative)
            case "H", "V": applied = applyAxis(kind, relative)
            case "C", "S": applied = applyCurve(kind, relative)
            case "Q", "T": applied = applyQuad(kind, relative)
            case "Z":
                current = start
                commands.append(.close)
                applied = true
            default: applied = false
            }
            if !"CSQT".contains(kind) { lastControl = nil }
            return applied
        }

        private mutating func applyPoint(_ kind: Character, _ relative: Bool) -> Bool {
            guard let point = point(relative) else { return false }
            current = point
            if kind == "M" {
                start = point
                commands.append(.move(point))
            } else {
                commands.append(.line(point))
            }
            return true
        }

        private mutating func applyAxis(_ kind: Character, _ relative: Bool) -> Bool {
            guard let value = number() else { return false }
            if kind == "H" {
                current.x = relative ? current.x + value : value
            } else {
                current.y = relative ? current.y + value : value
            }
            commands.append(.line(current))
            return true
        }

        private mutating func applyCurve(_ kind: Character, _ relative: Bool) -> Bool {
            let c1 = kind == "C" ? point(relative) : reflectedControl()
            guard let c1, let c2 = point(relative), let end = point(relative) else { return false }
            curve(to: end, c1, c2)
            return true
        }

        private mutating func applyQuad(_ kind: Character, _ relative: Bool) -> Bool {
            let control = kind == "Q" ? point(relative) : reflectedControl()
            guard let control, let end = point(relative) else { return false }
            quad(to: end, control)
            return true
        }

        private mutating func curve(to end: CGPoint, _ c1: CGPoint, _ c2: CGPoint) {
            commands.append(.curve(to: end, control1: c1, control2: c2))
            current = end
            lastControl = c2
        }

        private mutating func quad(to end: CGPoint, _ control: CGPoint) {
            commands.append(.quad(to: end, control: control))
            current = end
            lastControl = control
        }

        /// A shorthand's first control is the previous control mirrored through the current point.
        private func reflectedControl() -> CGPoint {
            guard let lastControl else { return current }
            return CGPoint(x: 2 * current.x - lastControl.x, y: 2 * current.y - lastControl.y)
        }

        private mutating func number() -> CGFloat? {
            guard index < tokens.count, let value = Double(tokens[index]) else { return nil }
            index += 1
            return CGFloat(value)
        }

        private mutating func point(_ relative: Bool) -> CGPoint? {
            guard let x = number(), let y = number() else { return nil }
            return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        }
    }
}
