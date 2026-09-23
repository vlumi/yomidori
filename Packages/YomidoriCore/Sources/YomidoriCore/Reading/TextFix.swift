/// A correction to recognized text: `length` characters at `offset` become `replacement`.
/// Fixes apply in order, each offset counted in the text as the fixes before it left it.
public struct TextFix: Equatable, Sendable {
    public let offset: Int
    public let length: Int
    public let replacement: String

    public init(offset: Int, length: Int, replacement: String) {
        self.offset = offset
        self.length = length
        self.replacement = replacement
    }

    public static func apply(_ fixes: [TextFix], to text: String) -> String {
        fixes.reduce(text) { text, fix in
            guard fix.offset >= 0, fix.offset + fix.length <= text.count else { return text }
            let start = text.index(text.startIndex, offsetBy: fix.offset)
            let end = text.index(start, offsetBy: fix.length)
            return text.replacingCharacters(in: start..<end, with: fix.replacement)
        }
    }

    /// Where a character of the unfixed text stands once the fixes are in; one inside a
    /// replaced run lands on the replacement's start.
    public static func map(offset: Int, through fixes: [TextFix]) -> Int {
        fixes.reduce(offset) { offset, fix in
            if offset >= fix.offset + fix.length {
                return offset + fix.replacement.count - fix.length
            }
            return offset >= fix.offset ? fix.offset : offset
        }
    }
}
