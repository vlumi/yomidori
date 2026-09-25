import Foundation

/// The forms a dictionary might list a tokenizer's cut under. The OS's analyzer cuts an
/// inflected verb at its stem (頷い + た), so the stem's last kana says which conjugation
/// rows it can come from; the dictionary decides which exist (降り is both 降る and 降りる).
public enum Deinflector {
    private struct Row {
        let replacing: [String]
        let takesRu: Bool
    }

    private static let rows: [Character: Row] = [
        // く/ぐ verbs before た/て (頷い, 泳い), or an ichidan stem in い (用い).
        "い": Row(replacing: ["く", "ぐ"], takesRu: true),
        // The t-form stem of う/つ/る verbs: 漂っ, 待っ, 黙っ; and 行っ from 行く.
        "っ": Row(replacing: ["う", "つ", "る", "く"], takesRu: false),
        // The n-form stem of む/ぶ/ぬ verbs: 微笑ん, 飛ん, 死ん.
        "ん": Row(replacing: ["む", "ぶ", "ぬ"], takesRu: false),
        // A godan masu-stem (指し → 指す), a suru verb's noun (存在し), or an ichidan stem
        // (起き).
        "し": Row(replacing: ["す", "する"], takesRu: true),
        "き": Row(replacing: ["く"], takesRu: true),
        "ぎ": Row(replacing: ["ぐ"], takesRu: true),
        "ち": Row(replacing: ["つ"], takesRu: true),
        "に": Row(replacing: ["ぬ"], takesRu: true),
        "ひ": Row(replacing: ["ふ"], takesRu: true),
        "び": Row(replacing: ["ぶ"], takesRu: true),
        "み": Row(replacing: ["む"], takesRu: true),
        "り": Row(replacing: ["る"], takesRu: true),
        // The e-row: an ichidan stem (点け → 点ける, 食べ → 食べる), or a godan verb's
        // potential or imperative cut before る/ない (負え → 負う, 読め → 読む).
        "け": Row(replacing: ["く"], takesRu: true),
        "げ": Row(replacing: ["ぐ"], takesRu: true),
        "せ": Row(replacing: ["す"], takesRu: true),
        "ぜ": Row(replacing: [], takesRu: true),
        "て": Row(replacing: ["つ"], takesRu: true),
        "で": Row(replacing: [], takesRu: true),
        "ね": Row(replacing: ["ぬ"], takesRu: true),
        "へ": Row(replacing: [], takesRu: true),
        "べ": Row(replacing: ["ぶ"], takesRu: true),
        "め": Row(replacing: ["む"], takesRu: true),
        "れ": Row(replacing: ["る"], takesRu: true),
        "え": Row(replacing: ["う"], takesRu: true),
        // An i-adjective's adverbial (古く → 古い).
        "く": Row(replacing: ["い"], takesRu: false),
        // The a-row: a godan stem before ない/れる/せる (照らさ → 照らす, 書か → 書く); か is
        // also an i-adjective's past stem cut before った (寒か → 寒い).
        "か": Row(replacing: ["い", "く"], takesRu: false),
        "さ": Row(replacing: ["す"], takesRu: false),
        "が": Row(replacing: ["ぐ"], takesRu: false),
        "た": Row(replacing: ["つ"], takesRu: false),
        "な": Row(replacing: ["ぬ"], takesRu: false),
        "ば": Row(replacing: ["ぶ"], takesRu: false),
        "ま": Row(replacing: ["む"], takesRu: false),
        "ら": Row(replacing: ["る"], takesRu: false),
        "わ": Row(replacing: ["う"], takesRu: false),
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

    /// Endings a tokenizer leaves on a verb or adjective, or cuts off as a word of their own
    /// (頼み + たい, where たい reads as 対): longest first.
    private static let endings = [
        "たくなかった", "たくない", "たかった", "たければ", "たくて", "たい", "たく",
        "ましょう", "ました", "ません", "ます", "なかった", "なければ", "なくて", "ない",
    ]

    /// A godan verb's volitional: the o-row kana and う (読もう → 読む, 行こう → 行く).
    private static let volitional: [Character: String] = [
        "こ": "く", "ご": "ぐ", "そ": "す", "と": "つ", "の": "ぬ", "ぼ": "ぶ", "も": "む",
        "ろ": "る", "お": "う",
    ]

    /// The dictionary forms of a verb or adjective with an ending on it (頼みたい → 頼む,
    /// 認めよう → 認める, 読もう → 読む, 勉強したい → 勉強 as a する noun), for when the word
    /// itself is not in the dictionary. Only a verb or adjective should be taken from these:
    /// the stem alone may be a noun.
    public static func conjugated(_ surface: String) -> [String] {
        var forms: [String] = []
        for ending in endings where surface.hasSuffix(ending) && surface.count > ending.count {
            forms += stemForms(String(surface.dropLast(ending.count)))
            break
        }
        // よう follows an ichidan stem, or する's し: 認めよう, 来よう, 勉強しよう.
        if surface.hasSuffix("よう"), surface.count > 2 {
            let stem = String(surface.dropLast(2))
            forms += stem.hasSuffix("し") ? stemForms(stem) : [stem + "る"]
        } else if surface.hasSuffix("う"), surface.count >= 3 {
            let before = surface.dropLast()
            if let last = before.last, let kana = volitional[last] {
                forms.append(String(before.dropLast()) + kana)
            }
        }
        return forms.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }

    /// What a stem cut from its ending may be listed as; a stem in し is also a する noun's
    /// (勉強し → 勉強).
    private static func stemForms(_ stem: String) -> [String] {
        var forms = Array(candidates(for: stem).dropFirst())
        if stem.hasSuffix("し"), stem.count > 1 { forms.append(String(stem.dropLast())) }
        return forms
    }
}
