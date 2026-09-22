import SwiftUI
import YomidoriCore

struct SensesList: View {
    let entry: DictionaryEntry
    var limit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entry.senses.prefix(limit).indices, id: \.self) { index in
                Text(
                    verbatim: "\(index + 1). \(entry.senses[index].glosses.joined(separator: "; "))"
                )
                .font(.callout)
            }
        }
    }
}
