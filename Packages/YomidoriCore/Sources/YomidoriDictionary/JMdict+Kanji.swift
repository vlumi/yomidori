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
            return KanjiEntry(
                literal: literal, onReadings: words(row[0]), kunReadings: words(row[1]),
                nanori: words(row[2]),
                meanings: row[3].isEmpty ? [] : row[3].components(separatedBy: "; "),
                strokes: Int(row[4]), grade: Int(row[5]), jlpt: Int(row[6]), frequency: Int(row[7]),
                components: components)
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

    private func words(_ joined: String) -> [String] {
        joined.split(separator: " ").map(String.init)
    }
}
