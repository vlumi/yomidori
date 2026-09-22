import SwiftUI

extension Text {
    /// Japanese content in either interface, tagged so VoiceOver speaks it with a Japanese
    /// voice rather than the interface's.
    init(japanese text: String) {
        var attributed = AttributedString(text)
        attributed.languageIdentifier = "ja"
        self.init(attributed)
    }
}
