import SwiftUI

/// Which side of the page its controls stand on, for the hand that holds the phone.
enum PageControlsSide: String, CaseIterable {
    case left
    case right

    var alignment: Alignment { self == .left ? .bottomLeading : .bottomTrailing }
    var horizontal: HorizontalAlignment { self == .left ? .leading : .trailing }
}

/// Everything done to the page, in one column on the chosen side: the spread's way out on
/// top, the next page, and the zoom at the bottom, nearest the thumb.
struct PageControls: View {
    let side: PageControlsSide
    /// The page's number in a spread; nil for a single page.
    let pageCount: Int?
    let canAddPage: Bool
    let addPage: () -> Void
    let startOver: () -> Void
    @Binding var zoom: Double

    var body: some View {
        VStack(alignment: side.horizontal, spacing: 14) {
            if let pageCount {
                StartOverButton(pageCount: pageCount, action: startOver)
            }
            PageButton(
                symbol: "plus", label: Text("Add next page", bundle: .module), action: addPage
            )
            .disabled(!canAddPage)
            ZoomSlider(fraction: $zoom)
        }
    }
}
