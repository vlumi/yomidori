import Foundation
import YomidoriCore

extension JMdict {
    public func kanji(_ literal: String) -> KanjiEntry? {
        queue.sync {
            guard
                let row = rows(
                    """
                    SELECT onyomi, kunyomi, nanori, meanings, strokes, grade, jlpt, freq
                    FROM kanji_info WHERE literal = ?1
                    """, bind: literal
                ).first
            else { return nil }
            let components = rows(
                "SELECT component FROM kanji_component WHERE literal = ?1 ORDER BY ord",
                bind: literal
            ).map { $0[0] }
            let strokes = rows(
                "SELECT path, label_x, label_y FROM kanji_stroke WHERE literal = ?1 ORDER BY ord",
                bind: literal
            ).map { row in KanjiStroke(path: row[0], label: point(row[1], row[2])) }
            return KanjiEntry(
                literal: literal, onReadings: words(row[0]), kunReadings: words(row[1]),
                nanori: words(row[2]),
                meanings: row[3].isEmpty ? [] : row[3].components(separatedBy: "; "),
                strokes: Int(row[4]), grade: Int(row[5]), jlpt: Int(row[6]), frequency: Int(row[7]),
                components: components, strokeOrder: strokes)
        }
    }

    public func entries(containing text: String, limit: Int) -> [DictionaryEntry] {
        queue.sync {
            rows(
                """
                SELECT DISTINCT e.id FROM kanji k JOIN entry e ON e.id = k.entry
                WHERE instr(k.text, ?1) > 0 AND k.text != ?1
                ORDER BY e.common DESC, length(k.text), e.id
                LIMIT \(limit)
                """, bind: text
            ).compactMap { Int($0[0]) }.map(entry(id:))
        }
    }

    public func kanjiParts() -> [KanjiPart] {
        queue.sync {
            rows(
                """
                SELECT c.component, k.strokes
                FROM (SELECT DISTINCT component FROM kanji_component) c
                LEFT JOIN kanji_info k ON k.literal = c.component
                ORDER BY k.strokes, c.component
                """, bind: nil
            ).map { KanjiPart(component: $0[0], strokes: Int($0[1])) }
        }
    }

    public func kanji(withParts parts: [String], limit: Int) -> [String] {
        guard !parts.isEmpty else { return [] }
        return queue.sync {
            rows(
                """
                SELECT c.literal FROM kanji_component c
                LEFT JOIN kanji_info k ON k.literal = c.literal
                WHERE c.component IN (\(placeholders(parts.count)))
                GROUP BY c.literal HAVING COUNT(DISTINCT c.component) = \(Set(parts).count)
                ORDER BY k.strokes IS NULL, k.strokes, k.freq IS NULL, k.freq, c.literal
                LIMIT \(limit)
                """, binds: parts
            ).map { $0[0] }
        }
    }

    public func parts(foundWith parts: [String]) -> Set<String> {
        guard !parts.isEmpty else { return [] }
        return queue.sync {
            Set(
                rows(
                    """
                    SELECT DISTINCT component FROM kanji_component WHERE literal IN (
                        SELECT literal FROM kanji_component
                        WHERE component IN (\(placeholders(parts.count)))
                        GROUP BY literal HAVING COUNT(DISTINCT component) = \(Set(parts).count))
                    """, binds: parts
                ).map { $0[0] })
        }
    }

    private func placeholders(_ count: Int) -> String {
        (1...count).map { "?\($0)" }.joined(separator: ", ")
    }

    private func point(_ x: String, _ y: String) -> CGPoint? {
        guard let x = Double(x), let y = Double(y) else { return nil }
        return CGPoint(x: x, y: y)
    }

    private func words(_ joined: String) -> [String] {
        joined.split(separator: " ").map(String.init)
    }
}
