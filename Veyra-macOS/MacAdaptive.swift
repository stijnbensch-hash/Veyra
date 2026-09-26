import SwiftUI

extension View {
    func veyraReadableWidth(_ maxWidth: CGFloat = 900) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}

struct VeyraPosterMetrics {
    let regular: Bool

    var posterWidth: CGFloat { regular ? 192 : 124 }
    var columns: [GridItem] {
        [GridItem(.adaptive(minimum: posterWidth), spacing: regular ? 26 : 16)]
    }
    var rowSpacing: CGFloat { regular ? 22 : 14 }
    var backdropHeight: CGFloat { 380 }
}
