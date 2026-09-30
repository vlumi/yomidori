import Foundation

/// The reader's corrections to a spread, each over the page text they were made on, as it
/// was recognized. A fix is an offset into a text, and means nothing in another: when a
/// page's text changes, read by another recognizer or taken again, its fixes stand aside,
/// and come back should that text return; the other page keeps its own throughout.
public struct SpreadFixes: Equatable, Sendable {
    /// The pages' texts as recognized, in reading order, trimmed as `Spread` joins them.
    public private(set) var texts: [String]
    /// Every page text fixed in this spread, with its fixes in the order they were made.
    private var byText: [String: [TextFix]]

    public init(texts: [String] = []) {
        self.texts = texts.map { $0.trimmingCharacters(in: .newlines) }
        byText = [:]
    }

    /// The same corrections over the pages as they read now.
    public func matching(_ texts: [String]) -> SpreadFixes {
        var matched = self
        matched.texts = texts.map { $0.trimmingCharacters(in: .newlines) }
        return matched
    }

    public func fixes(onPage index: Int) -> [TextFix] {
        texts.indices.contains(index) ? byText[texts[index]] ?? [] : []
    }

    public func hasFixes(onPage index: Int) -> Bool {
        !fixes(onPage: index).isEmpty
    }

    /// No page as it reads now has a fix.
    public var isEmpty: Bool {
        texts.indices.allSatisfy { !hasFixes(onPage: $0) }
    }

    /// The spread's text as recognized.
    public var text: String { Spread.join(texts) }

    /// Each page's text with its fixes in.
    public var fixedTexts: [String] {
        texts.indices.map { TextFix.apply(fixes(onPage: $0), to: texts[$0]) }
    }

    /// The spread's text with the fixes in.
    public var fixedText: String { Spread.join(fixedTexts) }

    /// Where a page starts in the fixed text.
    public func fixedOffset(ofPage index: Int) -> Int {
        Spread.offset(ofPage: index, in: fixedTexts)
    }

    /// The page an offset of the text as recognized falls on, and where on it.
    private func place(_ offset: Int) -> (page: Int, local: Int)? {
        var start = 0
        for (index, text) in texts.enumerated() where !text.isEmpty {
            if offset < start + text.count { return (index, offset - start) }
            start += text.count
        }
        // The end of the text, on its last page.
        if offset == start, let last = texts.lastIndex(where: { !$0.isEmpty }) {
            return (last, texts[last].count)
        }
        return nil
    }

    /// Where a character of the text as recognized stands once the fixes are in; one inside
    /// a replaced run lands on the replacement's start.
    public func map(offset: Int) -> Int {
        guard let (page, local) = place(offset) else { return offset }
        return fixedOffset(ofPage: page) + TextFix.map(offset: local, through: fixes(onPage: page))
    }

    /// A range of the text as recognized, in the fixed text: its last character is mapped as
    /// such, so a range ending inside a replaced run takes the replacement whole.
    public func map(_ range: Range<Int>) -> Range<Int> {
        let start = map(offset: range.lowerBound)
        guard !range.isEmpty, let (page, local) = place(range.upperBound - 1) else {
            return start..<start
        }
        let last = fixes(onPage: page).reduce(local) { last, fix in
            if last >= fix.offset + fix.length { return last + fix.replacement.count - fix.length }
            return last >= fix.offset ? fix.offset + fix.replacement.count - 1 : last
        }
        return start..<max(start, fixedOffset(ofPage: page) + last + 1)
    }

    /// A fix made on the fixed text, filed under the page it lies on; not taken when it
    /// spans two pages, or lies on none.
    @discardableResult
    public mutating func add(_ fix: TextFix) -> Bool {
        let fixed = fixedTexts
        var start = 0
        for (index, text) in fixed.enumerated() where !text.isEmpty {
            if fix.offset >= start, fix.offset + fix.length <= start + text.count {
                let local = TextFix(
                    offset: fix.offset - start, length: fix.length, replacement: fix.replacement)
                byText[texts[index], default: []].append(local)
                return true
            }
            start += text.count
        }
        return false
    }
}
