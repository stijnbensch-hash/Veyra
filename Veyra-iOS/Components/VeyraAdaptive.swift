import SwiftUI

extension View {
    /// Begrenst tekstrijke inhoud op iPad tot een gecentreerde kolom, zodat regels niet over het hele scherm lopen.
    /// Op iPhone is de breedte kleiner dan de grens en verandert er niets.
    func veyraReadableWidth(_ maxWidth: CGFloat = 900) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

/// Maten die afhangen van iPhone (compact) of iPad (regular).
struct VeyraPosterMetrics {
    let regular: Bool

    var posterWidth: CGFloat { regular ? 176 : 112 }
    var columns: [GridItem] {
        [GridItem(.adaptive(minimum: posterWidth), spacing: regular ? 20 : 12)]
    }
    var rowSpacing: CGFloat { regular ? 22 : 14 }
    var backdropHeight: CGFloat { regular ? 380 : 220 }
}
