import SwiftUI
import YomidoriCore

struct NoticesView: View {
    /// The notices parsed once, when the screen opens, not on every render.
    @State private var blocks: [MarkdownBlock] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(blocks.indices, id: \.self) { index in
                    render(blocks[index])
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(Text("Licenses and notices", bundle: .module))
        .task { blocks = MarkdownBlock.parse(AppInfo.notices) }
    }

    @ViewBuilder private func render(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(verbatim: text)
                .font(level <= 1 ? .title2.bold() : .headline)
                .padding(.top, level <= 1 ? 0 : 10)
        case .paragraph(let text):
            Text(inline(text))
                .font(.callout)
        case .quote(let text):
            Text(inline(text))
                .font(.callout)
                .italic()
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Palette.nightGreen).frame(width: 2)
                }
        case .code(let text):
            Text(verbatim: text)
                .font(.system(.caption, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    /// The raw text when the inline Markdown will not parse.
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}
