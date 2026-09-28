import SwiftUI

enum VeyraSpacing {
    static let page: CGFloat = 36
    static let submenuPage: CGFloat = 28
    static let rail: CGFloat = 38
}

enum VeyraRadius {
    static let poster: CGFloat = 16
    static let card: CGFloat = 20
    static let panel: CGFloat = 26
    static let pill: CGFloat = 44

    /// Veyra's eigen postervorm i.p.v. een uniform afgeronde rechthoek (de generieke
    /// "streaming-app"-look): twee sterker afgeronde hoeken diagonaal tegenover elkaar.
    /// Herkenbaar silhouet, ook los van kleur/gloei -- en werkt net zo goed in rust als
    /// bij focus (zie `VeyraPosterCard`).
    static var posterShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 26, bottomLeadingRadius: 8,
            bottomTrailingRadius: 26, topTrailingRadius: 8,
            style: .continuous
        )
    }
}

enum VeyraAnimation {
    static let focus = Animation.easeOut(duration: 0.16)
}
