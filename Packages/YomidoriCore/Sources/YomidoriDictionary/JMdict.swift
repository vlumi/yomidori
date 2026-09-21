import Foundation
import SQLite3
import YomidoriCore

/// The SQLite database `Scripts/data/build-jmdict.py` writes, read through the system's
/// SQLite C API.
public final class JMdict: WordDictionary {
    /// Nil in a checkout that has not run `make dictionary`.
    public static let bundled: JMdict? = {
        guard let url = Bundle.main.url(forResource: "jmdict", withExtension: "sqlite") else {
            return nil
        }
        return try? JMdict(url: url)
    }()

    public struct OpenError: Error {
        public let message: String
    }

    private var db: OpaquePointer?
    let queue = DispatchQueue(label: "fi.misaki.yomidori.jmdict")

    public init(url: URL) throws {
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "could not open"
            sqlite3_close(db)
            throw OpenError(message: message)
        }
    }

    deinit {
        sqlite3_close(db)
    }

    public var meta: [String: String] {
        queue.sync {
            var result: [String: String] = [:]
            for row in rows("SELECT key, value FROM meta", bind: nil) {
                result[row[0]] = row[1]
            }
            return result
        }
    }

    public func entries(matching text: String) -> [DictionaryEntry] {
        queue.sync {
            let ids = rows(
                """
                SELECT DISTINCT e.id FROM entry e
                LEFT JOIN kanji k ON k.entry = e.id
                LEFT JOIN reading r ON r.entry = e.id
                WHERE k.text = ?1 OR r.text = ?1
                ORDER BY e.common DESC, e.id
                """, bind: text
            ).compactMap { Int($0[0]) }
            return ids.map(entry(id:))
        }
    }

    public func pitchAccents(for headword: String, reading: String) -> [PitchAccent] {
        queue.sync {
            var statement: OpaquePointer?
            let sql = "SELECT downsteps FROM accent WHERE headword = ?1 AND reading = ?2"
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(statement) }
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, headword, -1, transient)
            sqlite3_bind_text(statement, 2, Kana.hiragana(reading), -1, transient)
            guard sqlite3_step(statement) == SQLITE_ROW,
                let text = sqlite3_column_text(statement, 0)
            else { return [] }
            return String(cString: text).split(separator: ",").compactMap { Int($0) }
                .map(PitchAccent.init(downstep:))
        }
    }

    public func search(_ query: String, limit: Int) -> [DictionaryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        switch SearchQuery.kind(of: trimmed) {
        case .empty:
            return []
        case .japanese:
            return queue.sync {
                /// JMdict spells loanwords in katakana, so a hiragana prefix is tried as
                /// katakana too.
                let katakana = Kana.katakana(trimmed)
                let ids = rows(
                    """
                    SELECT DISTINCT e.id FROM entry e
                    LEFT JOIN kanji k ON k.entry = e.id
                    LEFT JOIN reading r ON r.entry = e.id
                    WHERE (k.text >= ?1 AND k.text < ?2) OR (r.text >= ?1 AND r.text < ?2)
                       OR (r.text >= ?3 AND r.text < ?4)
                    ORDER BY e.common DESC, length(COALESCE(k.text, r.text)), e.id
                    LIMIT \(limit)
                    """,
                    binds: [trimmed, trimmed + "\u{10FFFF}", katakana, katakana + "\u{10FFFF}"]
                ).compactMap { Int($0[0]) }
                return ids.map(entry(id:))
            }
        case .gloss:
            return queue.sync {
                let terms = trimmed.split(separator: " ")
                    .map { "\"" + $0.replacingOccurrences(of: "\"", with: "") + "\"*" }
                let ids = rows(
                    """
                    SELECT DISTINCT s.entry FROM gloss_fts f
                    JOIN sense s ON s.rowid = f.rowid
                    JOIN entry e ON e.id = s.entry
                    WHERE gloss_fts MATCH ?1
                    ORDER BY e.common DESC, bm25(gloss_fts), e.id
                    LIMIT \(limit)
                    """, binds: [terms.joined(separator: " ")]
                ).compactMap { Int($0[0]) }
                return ids.map(entry(id:))
            }
        }
    }

    func entry(id: Int) -> DictionaryEntry {
        let idText = String(id)
        let kanji = rows("SELECT text FROM kanji WHERE entry = ?1 ORDER BY ord", bind: idText).map {
            $0[0]
        }
        let readings = rows("SELECT text FROM reading WHERE entry = ?1 ORDER BY ord", bind: idText)
            .map {
                $0[0]
            }
        let senses = rows(
            "SELECT pos, gloss FROM sense WHERE entry = ?1 ORDER BY ord", bind: idText
        ).map {
            DictionaryEntry.Sense(
                partsOfSpeech: $0[0].split(separator: " ").map(String.init),
                glosses: $0[1].components(separatedBy: "; "))
        }
        let common = rows("SELECT common FROM entry WHERE id = ?1", bind: idText).first?[0] == "1"
        return DictionaryEntry(
            id: id, kanji: kanji, readings: readings, senses: senses, common: common)
    }

    func rows(_ sql: String, bind: String?) -> [[String]] {
        rows(sql, binds: bind.map { [$0] } ?? [])
    }

    func rows(_ sql: String, binds: [String]) -> [[String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, bind) in binds.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), bind, -1, transient)
        }
        var result: [[String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let columns = Int(sqlite3_column_count(statement))
            result.append(
                (0..<columns).map { column in
                    sqlite3_column_text(statement, Int32(column)).map { String(cString: $0) } ?? ""
                })
        }
        return result
    }
}
