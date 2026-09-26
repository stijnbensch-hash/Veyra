import SwiftUI
import UIKit

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

    var posterWidth: CGFloat { regular ? 192 : 124 }
    var columns: [GridItem] {
        [GridItem(.adaptive(minimum: posterWidth), spacing: regular ? 26 : 16)]
    }
    var rowSpacing: CGFloat { regular ? 22 : 14 }
    // Op iPhone schaalt de hero mee met de schermhoogte, zodat hij
    // schermvullend en passend blijft op elk toestel -- een vaste waarde
    // (340) oogde op sommige schermen veel te groot.
    var backdropHeight: CGFloat {
        guard !regular else { return 380 }
        let screenHeight = UIScreen.main.bounds.height
        return min(420, max(300, screenHeight * 0.46))
    }
}
