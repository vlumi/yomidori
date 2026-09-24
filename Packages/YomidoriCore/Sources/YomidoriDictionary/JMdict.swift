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
    /// Only touched on `queue`: statements prepared once, and the entries and word matches
    /// already read, since a page asks for the same few thousand again and again.
    private var statements: [String: OpaquePointer] = [:]
    private var entryCache = BoundedCache<Int, DictionaryEntry>(limit: 8192)
    private var matchCache = BoundedCache<String, [Int]>(limit: 8192)

    public init(url: URL) throws {
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "could not open"
            // The object is whole by now, so deinit runs after the throw; the handle must be
            // gone before then or it is closed twice, which is a crash when the heap is reused.
            sqlite3_close(db)
            db = nil
            throw OpenError(message: message)
        }
    }

    deinit {
        statements.values.forEach { sqlite3_finalize($0) }
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

    /// Through the kanji and reading indexes, not a join with OR across them, which scans
    /// every entry: a tenth of a second per word, thousands of words to a page.
    public func entries(matching text: String) -> [DictionaryEntry] {
        queue.sync {
            let ids =
                matchCache[text]
                ?? rows(
                    """
                    SELECT e.id FROM entry e
                    WHERE e.id IN (
                        SELECT entry FROM kanji WHERE text = ?1
                        UNION SELECT entry FROM reading WHERE text = ?1)
                    ORDER BY e.common DESC, e.id
                    """, bind: text
                ).compactMap { Int($0[0]) }
            matchCache[text] = ids
            return ids.map(entry(id:))
        }
    }

    public func entries(spelledLike form: String, anyCharacterAt index: Int, limit: Int)
        -> [DictionaryEntry]
    {
        var characters = Array(form).map { character -> String in
            let text = String(character)
            return text == "%" || text == "_" || text == "\\" ? "\\" + text : text
        }
        guard characters.indices.contains(index) else { return [] }
        characters[index] = "_"
        let pattern = characters.joined()
        return queue.sync {
            let ids = rows(
                """
                SELECT DISTINCT e.id FROM kanji k JOIN entry e ON e.id = k.entry
                WHERE k.text LIKE ?1 ESCAPE '\\' AND k.text <> ?2
                ORDER BY e.common DESC, e.id LIMIT \(limit)
                """, binds: [pattern, form]
            ).compactMap { Int($0[0]) }
            return ids.map(entry(id:))
        }
    }

    public func pitchAccents(for headword: String, reading: String) -> [PitchAccent] {
        queue.sync {
            let downsteps =
                rows(
                    "SELECT downsteps FROM accent WHERE headword = ?1 AND reading = ?2",
                    binds: [headword, Kana.hiragana(reading)]
                ).first?[0] ?? ""
            return downsteps.split(separator: ",").compactMap { Int($0) }
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
                // JMdict spells loanwords in katakana, so a hiragana prefix is tried as
                // katakana too.
                let katakana = Kana.katakana(trimmed)
                let ids = rows(
                    """
                    SELECT e.id FROM (
                        SELECT entry, length(text) AS size FROM kanji
                        WHERE text >= ?1 AND text < ?2
                        UNION ALL SELECT entry, length(text) FROM reading
                        WHERE (text >= ?1 AND text < ?2) OR (text >= ?3 AND text < ?4)
                    ) m JOIN entry e ON e.id = m.entry
                    GROUP BY e.id
                    ORDER BY e.common DESC, MIN(m.size), e.id
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

    public func entry(withID id: Int) -> DictionaryEntry? {
        queue.sync {
            rows("SELECT id FROM entry WHERE id = ?1", bind: String(id)).isEmpty
                ? nil : entry(id: id)
        }
    }

    func entry(id: Int) -> DictionaryEntry {
        if let cached = entryCache[id] { return cached }
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
        let entry = DictionaryEntry(
            id: id, kanji: kanji, readings: readings, senses: senses, common: common)
        entryCache[id] = entry
        return entry
    }

    func rows(_ sql: String, bind: String?) -> [[String]] {
        rows(sql, binds: bind.map { [$0] } ?? [])
    }

    /// Run on `queue`; each SQL is prepared once and its statement kept. What SQL spells into
    /// itself (a LIMIT, a count of parts) takes few values, so few statements are kept.
    func rows(_ sql: String, binds: [String]) -> [[String]] {
        guard let statement = statement(sql) else { return [] }
        defer {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }
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

    private func statement(_ sql: String) -> OpaquePointer? {
        if let statement = statements[sql] { return statement }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return nil
        }
        statements[sql] = statement
        return statement
    }
}

/// A dictionary that forgets everything once it holds `limit` values: cheap, and enough for
/// what a reader looks at in one sitting.
struct BoundedCache<Key: Hashable, Value> {
    let limit: Int
    private var values: [Key: Value] = [:]

    init(limit: Int) {
        self.limit = limit
    }

    subscript(key: Key) -> Value? {
        get { values[key] }
        set {
            if values.count >= limit, values[key] == nil { values.removeAll(keepingCapacity: true) }
            values[key] = newValue
        }
    }
}
