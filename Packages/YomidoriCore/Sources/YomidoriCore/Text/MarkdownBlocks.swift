import Foundation

/// The block structure of a Markdown document, as much of it as a notices page
/// needs: headings, block quotes, fenced code, and paragraphs. Inline marks inside
/// a paragraph or heading are left for the text renderer, which understands them.
public enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case quote(String)
    case code(String)
    case paragraph(String)

    public static func parse(_ markdown: String) -> [MarkdownBlock] {
        var parser = Parser()
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            parser.take(String(line))
        }
        return parser.finish()
    }

    /// Line by line: a fence swallows everything to the next fence; a heading stands
    /// alone; quote lines and text lines gather until a blank line or a change of kind.
    private struct Parser {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var quote: [String] = []
        var code: [String]?

        mutating func take(_ line: String) {
            if let open = code {
                if line.hasPrefix("```") {
                    blocks.append(.code(open.joined(separator: "\n")))
                    code = nil
                } else {
                    code = open + [line]
                }
            } else if line.hasPrefix("```") {
                flush()
                code = []
            } else if let heading = heading(in: line) {
                flush()
                blocks.append(heading)
            } else if line.hasPrefix(">") {
                flushParagraph()
                quote.append(line.dropFirst().trimmingCharacters(in: .whitespaces))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flush()
            } else {
                flushQuote()
                paragraph.append(line.trimmingCharacters(in: .whitespaces))
            }
        }

        mutating func finish() -> [MarkdownBlock] {
            if let code {
                blocks.append(.code(code.joined(separator: "\n")))
            }
            flush()
            return blocks
        }

        private mutating func flush() {
            flushParagraph()
            flushQuote()
        }

        private mutating func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph = []
        }

        private mutating func flushQuote() {
            guard !quote.isEmpty else { return }
            blocks.append(.quote(quote.joined(separator: " ")))
            quote = []
        }

        private func heading(in line: String) -> MarkdownBlock? {
            let hashes = line.prefix { $0 == "#" }
            guard !hashes.isEmpty, hashes.count <= 6, line.dropFirst(hashes.count).first == " "
            else {
                return nil
            }
            let text = String(line.dropFirst(hashes.count)).trimmingCharacters(in: .whitespaces)
            return .heading(level: hashes.count, text: text)
        }
    }
}
