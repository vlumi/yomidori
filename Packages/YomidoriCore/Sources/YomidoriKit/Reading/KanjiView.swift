import SwiftUI
import YomidoriCore
import YomidoriDictionary

struct KanjiView: View {
    let kanji: KanjiEntry
    @State private var containing: [DictionaryEntry] = []

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 20) {
                    Text(japanese: kanji.literal)
                        .font(.system(size: 80))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: kanji.meanings.joined(separator: "; "))
                        facts
                    }
                    Spacer()
                    DictionaryButton(term: kanji.literal)
                        .labelStyle(.iconOnly)
                }
                .textSelection(.enabled)
            }
            if !kanji.strokeOrder.isEmpty {
                Section {
                    StrokeOrderView(strokes: kanji.strokeOrder)
                        .frame(maxWidth: .infinity)
                } header: {
                    Text("Stroke order", bundle: .module)
                }
            }
            Section {
                readings(Text("On", bundle: .module), kanji.onReadings)
                readings(Text("Kun", bundle: .module), kanji.kunReadings)
                readings(Text("In names", bundle: .module), kanji.nanori)
            } header: {
                Text("Readings", bundle: .module)
            }
            if !kanji.components.isEmpty {
                Section {
                    Text(verbatim: kanji.components.joined(separator: "  "))
                        .font(.title2)
                } header: {
                    Text("Components", bundle: .module)
                }
            }
            if !containing.isEmpty {
                Section {
                    ForEach(containing) { entry in
                        NavigationLink(value: entry) { EntryRow(entry: entry) }
                    }
                } header: {
                    Text("Words with \(kanji.literal)", bundle: .module)
                }
            }
        }
        .navigationTitle(Text(verbatim: kanji.literal))
        .task(id: kanji.literal) {
            let literal = kanji.literal
            containing =
                await Task.detached {
                    JMdict.bundled?.entries(containing: literal, limit: 60) ?? []
                }.value
        }
    }

    private var facts: some View {
        HStack(spacing: 8) {
            if let strokes = kanji.strokes {
                Text("\(strokes) strokes", bundle: .module)
            }
            if let grade = kanji.grade {
                KanjiGrade(grade: grade)
            }
            if let jlpt = kanji.jlpt {
                Text(verbatim: "JLPT \(jlpt)")
            }
            if let rank = kanji.frequency {
                Text("Rank \(rank)", bundle: .module)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder private func readings(_ label: Text, _ readings: [String]) -> some View {
        if !readings.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                label
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)
                Text(japanese: readings.joined(separator: "、"))
                    .foregroundStyle(Palette.nightGreen)
            }
            .textSelection(.enabled)
        }
    }
}

/// KANJIDIC's grades: 1 to 6 the primary school years, 8 secondary school, 9 and 10 the
/// kanji allowed in names.
struct KanjiGrade: View {
    let grade: Int

    var body: some View {
        switch grade {
        case 1...6:
            Text("Grade \(grade)", bundle: .module)
        case 8:
            Text("Secondary school", bundle: .module)
        case 9, 10:
            Text("Name kanji", bundle: .module)
        default:
            EmptyView()
        }
    }
}
