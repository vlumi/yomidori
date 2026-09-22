import SwiftUI
import YomidoriCore

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "ヨミドリ")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.nightGreen)
                    Text(verbatim: AppInfo.versionLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Point at a word, get its reading.", bundle: .module)
                        .padding(.top, 4)
                    Text(
                        // swiftlint:disable:next line_length
                        "Everything runs on this device: the camera, the text recognition, the dictionaries, your cards. Nothing is sent anywhere.",
                        bundle: .module
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            Section {
                legend("はな", 0, "Flat: low, then high to the end and beyond.")
                legend("あめ", 1, "Head-high: the first mora high, then low.")
                legend("うなずく", 3, "Mid-high: the drop after the numbered mora.")
                legend("はな", 2, "Tail-high: high to the end, the drop on what follows.")
            } header: {
                Text("How pitch is drawn", bundle: .module)
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "The line runs over the high morae and falls where the accent does; the number is the mora after which it falls, 0 when it never does. Tokyo accent, from Kanjium.",
                    bundle: .module)
            }
            Section {
                NavigationLink {
                    NoticesView()
                } label: {
                    Text("Licenses and notices", bundle: .module)
                }
            } header: {
                Text("Whose work this bundles", bundle: .module)
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "JMdict by the Electronic Dictionary Research and Development Group; KANJIDIC2, KRADFILE and KanjiVG for the kanji and their strokes; pitch accents from Kanjium by Uros O.; MeCab and IPADic; Mecab-Swift; manga-ocr. Their terms are inside.",
                    bundle: .module)
            }
        }
        .navigationTitle(Text("About", bundle: .module))
    }

    private func legend(_ reading: String, _ downstep: Int, _ key: LocalizedStringKey) -> some View
    {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            PitchReading(reading: reading, accent: PitchAccent(downstep: downstep))
                .frame(width: 130, alignment: .leading)
            Text(key, bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
