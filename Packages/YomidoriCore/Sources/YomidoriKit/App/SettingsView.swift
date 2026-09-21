import SwiftUI

struct SettingsView: View {
    @AppStorage(SwipeBack.key) private var swipeBack = true
    @AppStorage("typedAnswers") private var typedAnswers = false

    var body: some View {
        Form {
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
            Section {
                Toggle(isOn: $typedAnswers) {
                    Text("Type the reading", bundle: .module)
                }
            } footer: {
                Text(
                    "In a review, the reading is typed in kana and checked, instead of shown on a tap.",
                    bundle: .module)
            }
        }
        .tint(Palette.nightGreen)
        .navigationTitle(Text("Settings", bundle: .module))
    }
}
