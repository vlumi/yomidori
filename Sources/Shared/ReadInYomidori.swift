import AppIntents
import UniformTypeIdentifiers
import YomidoriKit

/// An action for Shortcuts: an image in, the Read tab open on it. After *Take Screenshot*, on
/// Back Tap or the Action button, it reads whatever is on the screen, a game's text drawn as
/// pictures included, and nothing is saved to Photos.
struct ReadInYomidori: AppIntent {
    static let title: LocalizedStringResource = "Read in Yomidori"
    static let description = IntentDescription(
        "Opens an image, a screenshot for one, on the Read tab, ready for its words to be tapped.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Image", supportedContentTypes: [.image])
    var image: IntentFile

    @MainActor
    func perform() async throws -> some IntentResult {
        guard StillInbox.shared.receive(image.data) else { throw Failure.notAnImage }
        return .result()
    }

    enum Failure: Error, CustomLocalizedStringResourceConvertible {
        case notAnImage

        var localizedStringResource: LocalizedStringResource {
            "That is not an image Yomidori can read."
        }
    }
}
