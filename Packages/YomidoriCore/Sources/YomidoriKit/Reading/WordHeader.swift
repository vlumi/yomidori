import SwiftUI
import YomidoriCore

/// The head of a word's screen — an entry, a card, a lesson's card: the word large with its
/// reading and pitch as the details have them, the dictionary button beside, and whatever
/// else the screen puts there.
struct WordHeader<Trailing: View>: View {
    let headword: String
    let reading: String
    let details: WordDetails
    @ViewBuilder var trailing: () -> Trailing

    init(
        headword: String, reading: String, details: WordDetails,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.headword = headword
        self.reading = reading
        self.details = details
        self.trailing = trailing
    }

    var body: some View {
        Section {
            WordTitle(
                headword: headword, reading: reading, accent: details.accent(of: reading),
                estimate: details.estimate, font: .largeTitle
            ) {
                DictionaryButton(term: headword)
                    .labelStyle(.iconOnly)
                    .help(Text("Dictionary", bundle: .module))
                trailing()
            }
        }
    }
}
