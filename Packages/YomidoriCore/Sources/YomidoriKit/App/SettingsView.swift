import SwiftUI

struct SettingsView: View {
    @AppStorage(SwipeBack.key) private var swipeBack = true
    @AppStorage(TokenizerChoice.key) private var tokenizer: TokenizerChoice = .system

    var body: some View {
        Form {
            Section {
                Picker(selection: $tokenizer) {
                    Text("System", bundle: .module).tag(TokenizerChoice.system)
                    Text(verbatim: "MeCab").tag(TokenizerChoice.mecab)
                } label: {
                    Text("Tokenizer", bundle: .module)
                }
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "Which analyzer cuts a page into words. The system's is the default; MeCab is here to compare on real pages.",
                    bundle: .module)
            }
            Section {
                Toggle(isOn: $swipeBack) {
                    Text("Swipe back", bundle: .module)
                }
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "Swiping in from the left edge goes back a screen, as everywhere on iOS. Off, only the back button does, so a swipe meant for a word never leaves the page.",
                    bundle: .module)
            }
        }
        .tint(Palette.nightGreen)
        .navigationTitle(Text("Settings", bundle: .module))
    }
}
