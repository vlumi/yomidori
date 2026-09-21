import PhotosUI
import SwiftUI

struct CameraButtons: View {
    @Binding var picked: PhotosPickerItem?
    let ready: Bool
    let shutter: () -> Void

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
            Button(action: shutter) {
                Circle()
                    .strokeBorder(Palette.nightGreen, lineWidth: 4)
                    .background(Circle().fill(.white))
                    .frame(width: 72, height: 72)
            }
            .accessibilityLabel(Text("Shutter", bundle: .module))
            .disabled(!ready)
            .opacity(ready ? 1 : 0.4)
            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
        }
    }
}

struct StillButtons: View {
    let canAddPage: Bool
    let hasPages: Bool
    let retake: () -> Void
    let addPage: () -> Void
    let startOver: () -> Void

    var body: some View {
        HStack {
            Button(action: retake) {
                Label {
                    Text("Retake", bundle: .module)
                } icon: {
                    Image(systemName: "camera")
                }
            }
            .buttonStyle(.bordered)
            if canAddPage {
                Button(action: addPage) {
                    Label {
                        Text("Add next page", bundle: .module)
                    } icon: {
                        Image(systemName: "plus.rectangle.portrait")
                    }
                }
                .buttonStyle(.bordered)
            }
            if hasPages {
                Button(action: startOver) {
                    Text("Start over", bundle: .module)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
