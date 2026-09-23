import PhotosUI
import SwiftUI

struct CameraButtons: View {
    @Binding var picked: PhotosPickerItem?
    let ready: Bool
    let label: Text
    let freeze: () -> Void
    /// Where the text of a paste goes; nil where only an image will do.
    var paste: ((String) -> Void)?

    var body: some View {
        HStack {
            PhotosPicker(selection: $picked, matching: .images) {
                Label {
                    Text("Choose a photo", bundle: .module)
                } icon: {
                    Image(systemName: "photo.on.rectangle")
                }
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .frame(maxWidth: .infinity)
            Button(action: freeze) {
                Image(systemName: "text.viewfinder")
                    .font(.title.weight(.semibold))
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(Palette.nightGreen)
            .accessibilityLabel(label)
            .disabled(!ready)
            if let paste {
                // The system's own button pastes without asking, since the tap is the consent.
                PasteButton(payloadType: String.self) { strings in
                    if let text = strings.first {
                        Task { @MainActor in paste(text) }
                    }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
                .tint(Palette.nightGreen)
                .frame(maxWidth: .infinity)
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
            }
        }
    }
}
