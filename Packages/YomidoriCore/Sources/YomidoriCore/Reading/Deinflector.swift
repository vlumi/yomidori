import Foundation

/// The forms a dictionary might list a tokenizer's cut under. The OS's analyzer cuts an
/// inflected verb at its stem (頷い + た), so the stem's last kana says which conjugation
/// rows it can come from; the dictionary decides which exist (降り is both 降る and 降りる).
public enum Deinflector {
    private struct Row {
        let replacing: [String]
        let takesRu: Bool
        /// The stem is also an i-adjective's, before さ or そう: い goes on the end.
        var takesI = false
        /// The ichidan verb comes before the godan one: an e-row stem before た, て or
        /// ながら is an ichidan verb's (見せ → 見せる, 捨て → 捨てる), and the godan verbs the
        /// row also spells are mostly the old ones (見す, 捨つ).
        var ruFirst = false
    }

    private static let rows: [Character: Row] = [
        // く/ぐ verbs before た/て (頷い, 泳い), an う verb's masu-stem (笑い, 思い), or an
        // ichidan stem in い (用い).
        "い": Row(replacing: ["く", "ぐ", "う"], takesRu: true),
        // The t-form stem of う/つ/る verbs: 漂っ, 待っ, 黙っ; and 行っ from 行く.
        "っ": Row(replacing: ["う", "つ", "る", "く"], takesRu: false),
        // The n-form stem of む/ぶ/ぬ verbs: 微笑ん, 飛ん, 死ん.
        "ん": Row(replacing: ["む", "ぶ", "ぬ"], takesRu: false),
        // A godan masu-stem (指し → 指す), a suru verb's noun (存在し), an ichidan stem
        // (起き), or an i-adjective's stem before さ or そう (嬉し → 嬉しい, 大き → 大きい).
        "し": Row(replacing: ["す", "する"], takesRu: true, takesI: true),
        // An ichidan stem in じ (感じ → 感じる, 信じ, 命じ).
        "じ": Row(replacing: [], takesRu: true),
        "き": Row(replacing: ["く"], takesRu: true, takesI: true),
        "ぎ": Row(replacing: ["ぐ"], takesRu: true),
        "ち": Row(replacing: ["つ"], takesRu: true),
        "に": Row(replacing: ["ぬ"], takesRu: true),
        "ひ": Row(replacing: ["ふ"], takesRu: true),
        "び": Row(replacing: ["ぶ"], takesRu: true),
        "み": Row(replacing: ["む"], takesRu: true),
        "り": Row(replacing: ["る"], takesRu: true),
        // The e-row: an ichidan stem (点け → 点ける, 食べ → 食べる), or a godan verb's
        // potential or imperative cut before る/ない (負え → 負う, 読め → 読む).
        "け": Row(replacing: ["く"], takesRu: true, ruFirst: true),
        "げ": Row(replacing: ["ぐ"], takesRu: true, ruFirst: true),
        "せ": Row(replacing: ["す"], takesRu: true, ruFirst: true),
        "ぜ": Row(replacing: [], takesRu: true),
        "て": Row(replacing: ["つ"], takesRu: true, ruFirst: true),
        "で": Row(replacing: [], takesRu: true),
        "ね": Row(replacing: ["ぬ"], takesRu: true, ruFirst: true),
        "へ": Row(replacing: [], takesRu: true),
        "べ": Row(replacing: ["ぶ"], takesRu: true, ruFirst: true),
        "め": Row(replacing: ["む"], takesRu: true, ruFirst: true),
        "れ": Row(replacing: ["る"], takesRu: true, ruFirst: true),
        "え": Row(replacing: ["う"], takesRu: true, ruFirst: true),
        // An i-adjective's adverbial (古く → 古い).
        "く": Row(replacing: ["い"], takesRu: false),
        // The a-row: a godan stem before ない/れる/せる (照らさ → 照らす, 書か → 書く); か is
        // also an i-adjective's past stem cut before った (寒か → 寒い).
        "か": Row(replacing: ["い", "く"], takesRu: false),
        "さ": Row(replacing: ["す"], takesRu: false),
        "が": Row(replacing: ["ぐ"], takesRu: false),
        // 待た(ない) → 待つ; and an i-adjective's stem before さ or そう (冷た → 冷たい).
        "た": Row(replacing: ["つ"], takesRu: false, takesI: true),
        "な": Row(replacing: ["ぬ"], takesRu: false),
        "ば": Row(replacing: ["ぶ"], takesRu: false),
        "ま": Row(replacing: ["む"], takesRu: false),
        "ら": Row(replacing: ["る"], takesRu: false),
        "わ": Row(replacing: ["う"], takesRu: false),
    ]

    public static func candidates(for surface: String) -> [String] {
        // A bare kanji before た or て is an ichidan verb cut to its stem (見, 出, 寝, 着),
        // or 来る; the dictionary decides, and a kanji that is no verb's stem stays a word.
        if surface.count == 1, !Kana.isKana(surface) { return [surface, surface + "る"] }
        // An i-adjective's stems before た and ば: 美しかっ → 美しい, 寒けれ → 寒い.
        for (ending, count) in [("かっ", 2), ("けれ", 2)] where surface.hasSuffix(ending) {
            guard surface.count > count else { break }
            return [surface, String(surface.dropLast(count)) + "い"]
        }
        guard surface.count >= 2, let last = surface.last, let row = rows[last] else {
            return [surface]
        }
        let stem = String(surface.dropLast())
        var forms = [surface]
        if row.takesRu, row.ruFirst { forms.append(surface + "る") }
        forms += row.replacing.map { stem + $0 }
        if row.takesRu, !row.ruFirst { forms.append(surface + "る") }
        if row.takesI {
            forms.append(surface + "い")
        }
        return forms.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }

    /// Whether the surface is a stem a tokenizer cuts an ending from: one a row knows, or
    /// an adjective's.
    public static func isStem(_ surface: String) -> Bool {
        candidates(for: surface).count > 1
    }

    /// What the OS's analyzer cuts off after a verb's or an adjective's stem, as a token of
    /// its own: た, て, ながら, ます, ない and their kin. A stem before one of these is a
    /// verb or an adjective whatever else the dictionary spells the same way (吹き出し the
    /// noun, 吹き出した the verb).
    public static let attachedEndings: Set<String> = [
        "た", "たら", "たり", "て", "ながら", "つつ", "ます", "まし", "ましょ", "ません", "たい",
        "たく", "たかっ", "たけれ", "ない", "なかっ", "なけれ", "なく", "ず", "ぬ", "そう", "ば", "れ",
        "られ", "せ", "させ", "すぎ", "ちゃっ", "ちゃう", "てる", "とく", "しまっ", "しまう", "よう",
        "まい", "さ", "やすい", "やすく", "にくい", "にくく", "がち", "っぽい", "かた", "方",
    ]

    /// Whether `next` is an ending attached to `stem`: で and でる only after the ん and い
    /// stems whose て turns voiced (読ん + で), since after a noun で is a particle.
    public static func isEnding(_ next: String, after stem: String) -> Bool {
        if next == "で" || next == "でる" { return stem.hasSuffix("ん") || stem.hasSuffix("い") }
        return attachedEndings.contains(next)
    }

    /// What follows an ending as more of the same inflection (見 + て + い + た, 住ん + で +
    /// いる): the endings again, and the auxiliaries いる, おる, ある and くる in their cuts.
    public static func continuesInflection(_ next: String) -> Bool {
        attachedEndings.contains(next)
            || [
                "で", "でる", "い", "いる", "いた", "いれ", "おり", "おる", "あっ", "ある", "き", "くる", "く", "いっ",
                "いく", "みる", "み", "おく", "おい",
            ].contains(next)
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
