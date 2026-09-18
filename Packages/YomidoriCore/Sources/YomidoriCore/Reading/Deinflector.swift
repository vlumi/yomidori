import Foundation

/// From a word as the tokenizer cut it to the forms a dictionary might list it
/// under. The OS's analyzer cuts an inflected verb at its stem (頷い + た, 漂っ + て),
/// so the stem's last kana says which conjugation rows it can come from; each row
/// gives one candidate, and the dictionary decides which exist (降り is both 降る
/// and 降りる). The word itself is always the first candidate, for nouns and for
/// anything already in its dictionary form.
public enum Deinflector {
    /// What a stem's last kana can turn into: endings that replace it, and whether
    /// the stem can also be an ichidan stem that just takes る.
    private struct Row {
        let replacing: [String]
        let takesRu: Bool
    }

    private static let rows: [Character: Row] = [
        // The continuative of く/ぐ verbs before た/て: 頷い(た), 泳い(だ); or an ichidan
        // stem ending in い: 用い(る).
        "い": Row(replacing: ["く", "ぐ"], takesRu: true),
        // The t-form stem of う/つ/る verbs: 漂っ, 待っ, 黙っ; and 行っ from 行く.
        "っ": Row(replacing: ["う", "つ", "る", "く"], takesRu: false),
        // The n-form stem of む/ぶ/ぬ verbs: 微笑ん, 飛ん, 死ん.
        "ん": Row(replacing: ["む", "ぶ", "ぬ"], takesRu: false),
        // The i-row: a godan masu-stem (指し → 指す, 打ち → 打つ), a suru verb's noun
        // (存在し → 存在する), or an ichidan stem (起き → 起きる, 降り → 降りる).
        "し": Row(replacing: ["す", "する"], takesRu: true),
        "き": Row(replacing: ["く"], takesRu: true),
        "ぎ": Row(replacing: ["ぐ"], takesRu: true),
        "ち": Row(replacing: ["つ"], takesRu: true),
        "に": Row(replacing: ["ぬ"], takesRu: true),
        "ひ": Row(replacing: ["ふ"], takesRu: true),
        "び": Row(replacing: ["ぶ"], takesRu: true),
        "み": Row(replacing: ["む"], takesRu: true),
        "り": Row(replacing: ["る"], takesRu: true),
        // The e-row: an ichidan stem (点け → 点ける, 食べ → 食べる).
        "け": Row(replacing: [], takesRu: true),
        "げ": Row(replacing: [], takesRu: true),
        "せ": Row(replacing: [], takesRu: true),
        "ぜ": Row(replacing: [], takesRu: true),
        "て": Row(replacing: [], takesRu: true),
        "で": Row(replacing: [], takesRu: true),
        "ね": Row(replacing: [], takesRu: true),
        "へ": Row(replacing: [], takesRu: true),
        "べ": Row(replacing: [], takesRu: true),
        "め": Row(replacing: [], takesRu: true),
        "れ": Row(replacing: [], takesRu: true),
        "え": Row(replacing: [], takesRu: true),
        // An i-adjective's adverbial (古く) or its past stem cut before っ (寒か).
        "く": Row(replacing: ["い"], takesRu: false),
        "か": Row(replacing: ["い"], takesRu: false),
    ]

    public static func candidates(for surface: String) -> [String] {
        guard surface.count >= 2, let last = surface.last, let row = rows[last] else {
            return [surface]
        }
        let stem = String(surface.dropLast())
        var forms = [surface] + row.replacing.map { stem + $0 }
        if row.takesRu {
            forms.append(surface + "る")
        }
        return forms.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }
}
