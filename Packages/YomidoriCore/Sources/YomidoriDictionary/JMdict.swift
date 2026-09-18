import Foundation
import SQLite3
import YomidoriCore

/// The bundled JMdict, as the SQLite database `Scripts/data/build-jmdict.py` writes:
/// opened read-only, queried by exact kanji form or reading. The C API of the
/// system's SQLite, no third-party code.
public final class JMdict: WordDictionary {
    /// The database in the app bundle, or nil where there is none (the tests' build,
    /// a checkout that has not run `make dictionary`).
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
    private let queue = DispatchQueue(label: "fi.misaki.yomidori.jmdict")

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

    /// What the database says about itself: source, creation date, license, attribution.
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

    private func entry(id: Int) -> DictionaryEntry {
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

    /// Every row of a query as its columns' text; one optional text bound to ?1.
    private func rows(_ sql: String, bind: String?) -> [[String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        if let bind {
            sqlite3_bind_text(
                statement, 1, bind, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
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
