/// The one key a word has across the cards, the history and a search: headword and reading.
public enum WordKey {
    public static func of(headword: String, reading: String) -> String {
        "\(headword) \(reading)"
    }
}
