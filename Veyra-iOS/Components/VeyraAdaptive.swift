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

/// Drie catalogusposters op iPhone; behoud de postermaat door de vrije ruimte
/// eerst uit marges en kolomafstand te halen. iPad behoudt het adaptieve raster.
struct VeyraCatalogPosterGridLayout {
    let availableWidth: CGFloat
    let regular: Bool
    private var metrics: VeyraPosterMetrics { VeyraPosterMetrics(regular: regular) }
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    var posterWidth: CGFloat {
        isPhone ? min(124, max(1, (availableWidth - 8) / 3)) : metrics.posterWidth
    }
    var horizontalPadding: CGFloat {
        isPhone ? min(16, max(0, (availableWidth - 3 * posterWidth - 16) / 2)) : 16
    }
    var columns: [GridItem] {
        guard isPhone else { return metrics.columns }
        let spacing = max(4, (availableWidth - 2 * horizontalPadding - 3 * posterWidth) / 2)
        return Array(repeating: GridItem(.fixed(posterWidth), spacing: spacing), count: 3)
    }
    var rowSpacing: CGFloat { metrics.rowSpacing }
}
