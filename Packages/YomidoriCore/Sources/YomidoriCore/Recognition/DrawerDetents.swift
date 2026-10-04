import CoreGraphics

/// Where the drawer under a page comes to rest, as fractions of the screen: a strip for the
/// page, half, most of the screen.
public enum DrawerDetents {
    public static let fractions: ClosedRange<Double> = 0.2...0.8
    public static let all: [Double] = [0.2, 0.5, 0.8]

    public static func nearest(_ fraction: Double) -> Double {
        all.min { abs($0 - fraction) < abs($1 - fraction) } ?? fraction
    }

    /// Never under 180 points, the handle and one word's row.
    public static func height(fraction: Double, screenHeight: CGFloat) -> CGFloat {
        max(180, screenHeight * fraction)
    }

    /// A double tap on the handle: the drawer to its largest, remembering where it stood, or
    /// from its largest back to where it stood, else to its smallest. Returns the fraction
    /// to settle at and what to remember for the next toggle.
    public static func toggled(from settled: Double, remembered: Double?) -> (
        settle: Double, remember: Double?
    ) {
        let largest = all.last ?? fractions.upperBound
        if settled >= largest {
            return (remembered ?? all[0], nil)
        }
        return (largest, settled)
    }

    /// The fraction under a finger that landed at `start` and has moved `dy` points down.
    public static func dragged(from start: Double, by dy: CGFloat, screenHeight: CGFloat) -> Double
    {
        min(max(start - dy / screenHeight, fractions.lowerBound), fractions.upperBound)
    }
}
