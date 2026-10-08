/// The defaults keys the screens share; the demo writes some of them too.
enum SettingsKey {
    static let readoutFraction = "readoutFraction"
    static let transcriptExpanded = "transcriptExpanded"
    static let lessonOrder = "lessonOrder"
    static let lessonSize = "lessonSize"
    static let iCloudSync = "iCloudSync"
    static let pageControlsSide = "pageControlsSide"
    static let appBadge = "appBadge"
    /// The share of reviews the schedule aims to have come out right, 0.9 or 0.95.
    static let retention = "retention"
    /// The app's language, an `AppLanguage`.
    static let language = "language"
    /// The app's look, an `Appearance`.
    static let appearance = "appearance"
    /// The iPad's Read on its side: the words column's width, as dragged.
    static let wordsColumnWidth = "wordsColumnWidth"
    /// The Mac's search: the history column shown.
    static let historyShown = "historyShown"
    /// The card list's order, a `CardSort`, and the kind of word it shows, a `WordClass`'s
    /// name or nothing for every kind.
    static let cardSort = "cardSort"
    static let cardWordClass = "cardWordClass"
    /// Study's Coming up bars colored by what each question asks, not by rank.
    static let upcomingByQuestion = "upcomingByQuestion"
    /// How many days Study's Coming up looks ahead, 7 or 30.
    static let upcomingDays = "upcomingDays"
}
