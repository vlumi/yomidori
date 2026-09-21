import SwiftUI

struct CloseUpReadout: View {
    let reading: Bool
    let closeUp: CaptureView.CloseUp?

    var body: some View {
        if reading {
            ProgressView {
                Text("Reading up close…", bundle: .module)
            }
        } else if let closeUp {
            HStack(alignment: .top, spacing: 12) {
                Image(decorative: closeUp.crop.image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 160, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 6) {
                    EngineLine(name: "Live Text", text: closeUp.liveText)
                    EngineLine(name: "Vision", text: closeUp.vision)
                    if let manga = closeUp.mangaOCR {
                        EngineLine(name: "manga-ocr", text: manga)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Tap a word to read it up close.", bundle: .module)
                .foregroundStyle(.secondary)
        }
    }
}
