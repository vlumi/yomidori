import Foundation
import UniformTypeIdentifiers

extension Still {
    /// The picture among what was dropped or pasted — image data, or a file on this machine
    /// — handed over once decoded; false when nothing there is a picture. Only the first
    /// item counts: one page at a time.
    @discardableResult
    static func take(
        from providers: [NSItemProvider], _ take: @escaping @MainActor (Still) -> Void
    ) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(for: .image) { data, _ in
                guard let data, let still = Still(data: data) else { return }
                Task { @MainActor in take(still) }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil),
                    let still = Still(file: url)
                else { return }
                Task { @MainActor in take(still) }
            }
            return true
        }
        return false
    }

    /// A picture file picked by the reader, decoded off the main thread.
    static func take(
        picked result: Result<URL, Error>, _ take: @escaping @MainActor (Still) -> Void
    ) {
        guard let url = try? result.get() else { return }
        decode(file: url, then: take)
    }
}
