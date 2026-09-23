import PhotosUI
import SwiftUI
import VisionKit
import YomidoriCore

/// A book cover through the camera or from the photos: the picture becomes the collection's
/// cover, and the words read off it are offered for the name and the note, the largest
/// print first, so a title need not be typed.
struct CoverScanView: View {
    @Binding var collection: Collection
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = Camera()
    @State private var still: Still?
    @State private var lines: [String] = []
    @State private var reading = false
    @State private var picked: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Group {
                if let still {
                    read(still)
                } else {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        CameraPreview(camera: camera, access: camera.access, freeze: takeStill)
                            .ignoresSafeArea()
                        CameraNotice(access: camera.access)
                    }
                    .safeAreaInset(edge: .bottom) {
                        CameraButtons(
                            picked: $picked, ready: camera.access == .ready,
                            label: Text("Scan the cover", bundle: .module), freeze: takeStill
                        )
                        .padding(16)
                        .background(Palette.page)
                    }
                }
            }
            .navigationTitle(Text("Cover", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", bundle: .module)
                    }
                }
                if still != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            keep()
                        } label: {
                            Text("Use", bundle: .module)
                        }
                    }
                }
            }
            .onAppear { camera.start() }
            .onDisappear { camera.stop() }
            .task(id: picked) { await loadPicked() }
            .task(id: still?.id) { await recognize() }
            .tint(Palette.nightGreen)
        }
    }

    private func read(_ still: Still) -> some View {
        List {
            picture(still)
            Section {
                TextField(text: $collection.name) {
                    Text("Name", bundle: .module)
                }
                TextField(text: $collection.note) {
                    Text("Note, an author say", bundle: .module)
                }
            }
            readLines
        }
    }

    private func picture(_ still: Still) -> some View {
        Section {
            Image(decorative: still.image, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button {
                self.still = nil
                camera.start()
            } label: {
                Label {
                    Text("Retake", bundle: .module)
                } icon: {
                    Image(systemName: "camera")
                }
            }
        }
    }

    private var readLines: some View {
        Section {
            if reading {
                ProgressView()
            } else if lines.isEmpty {
                Text("Nothing was read off the cover.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(lines, id: \.self) { line in
                FitsOrStacks {
                    Text(japanese: line)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        collection.name = line
                    } label: {
                        Text("Name", bundle: .module)
                    }
                    Button {
                        collection.note = line
                    } label: {
                        Text("Note", bundle: .module)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } header: {
            Text("Read off the cover", bundle: .module)
        }
    }

    private func takeStill() {
        Task { @MainActor in
            if let taken = await camera.takeStill() {
                camera.stop()
                still = taken
            }
        }
    }

    private func loadPicked() async {
        guard let picked, let data = try? await picked.loadTransferable(type: Data.self),
            let loaded = Still(data: data), !Task.isCancelled
        else { return }
        camera.stop()
        still = loaded
    }

    private func recognize() async {
        lines = []
        guard let still else { return }
        reading = true
        let recognized = (try? await TextRecognizer.recognize(still)) ?? []
        let transcript =
            LiveText.isSupported ? (try? await LiveText.analyze(still))?.transcript : nil
        guard !Task.isCancelled else { return }
        lines = CoverLines.merge(vision: recognized, liveText: transcript)
        reading = false
    }

    private func keep() {
        if let still, let id = try? CoverArchive.save(still.image) {
            collection.coverID = id
        }
        dismiss()
    }
}
