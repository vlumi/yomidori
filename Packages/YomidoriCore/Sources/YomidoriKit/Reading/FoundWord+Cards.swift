import YomidoriCore

extension FoundWord {
    /// The reading the word's card is filed under: a twin card's where one exists.
    var filedReading: String {
        Cards.filedReading(headword: cardHeadword, reading: cardReading)
    }
}
