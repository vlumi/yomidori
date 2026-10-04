import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The shutter in the middle, and the other ways in either side of it: the photo library
/// and a file on the left, the pasteboard on the right.
struct CameraButtons: View {
    @Binding var picked: PhotosPickerItem?
    let ready: Bool
    let label: Text
    let freeze: () -> Void
    /// Where the text of a paste goes; nil where only an image will do.
    var paste: ((String) -> Void)?
    /// Where a pasted picture goes, and a file's; nil where the photo library is the only
    /// way in besides the camera.
    var take: ((Still) -> Void)?
    @State private var opening = false

    var body: some View {
        HStack {
            HStack {
                PhotosPicker(selection: $picked, matching: .images) {
                    Label {
                        Text("Choose a photo", bundle: .module)
                    } icon: {
                        Image(systemName: "photo.on.rectangle")
                            .turnsWithPhone()
                    }
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .frame(maxWidth: .infinity)
                if let take {
                    Button {
                        opening = true
                    } label: {
                        Label {
                            Text("Open a picture file", bundle: .module)
                        } icon: {
                            Image(systemName: "folder")
                                .turnsWithPhone()
                        }
                    }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .fileImporter(isPresented: $opening, allowedContentTypes: [.image]) { result in
                        Still.take(picked: result, take)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            Button(action: freeze) {
                Image(systemName: "text.viewfinder")
                    .turnsWithPhone()
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
                // A picture first, where there is one and somewhere for it to go.
                let types: [UTType] = take == nil ? [.plainText] : [.image, .plainText]
                PasteButton(supportedContentTypes: types) { providers in
                    if let take, Still.take(from: providers, take) { return }
                    providers.first?.loadObject(ofClass: NSString.self) { object, _ in
                        guard let text = object as? String else { return }
                        Task { @MainActor in paste(text) }
                    }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
                .tint(Palette.nightGreen)
                .turnsWithPhone()
                .frame(maxWidth: .infinity)
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
            }
        }
    }
}
