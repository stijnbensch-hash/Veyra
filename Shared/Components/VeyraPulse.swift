// VeyraPulse.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// "Veyra Pulse": één klein, herkenbaar contextueel label dat overal dezelfde vorm en functie
// heeft, ongeacht content-type — icoon + korte tekst in een glazen pil, in dezelfde stijl als
// de bestaande poster-badges (zie `VeyraPosterCard.posterBadgeFill`/`VeyraFrame`). Film/serie
// gebruiken vandaag al `ContinueItem.metaText`/`shortMetaText` als brontekst; Pulse geeft die
// bestaande info enkel een consistent, herkenbaar uiterlijk (icoon + pil) i.p.v. losse tekst,
// zodat het systeem later ook voor Live TV/Sport hergebruikt kan worden zonder nieuwe stijl.

import SwiftUI

enum VeyraPulseDefaults {
    /// Eén instelling, overal dezelfde: geen los tvOS/iOS/macOS-schakelaartje. Standaard aan
    /// zodat bestaand gedrag (cyaan teksten in het onderschrift) zichtbaar verbetert i.p.v.
    /// verandert; uitzetten valt terug op de vorige, kale teksten.
    static let enabledKey = "general.pulseBadgesEnabled"
}

nonisolated enum VeyraPulseKind: Sendable {
    case movie, series, live, sport

    var symbol: String {
        switch self {
        case .movie: return "film"
        case .series: return "tv"
        case .live: return "dot.radiowaves.left.and.right"
        case .sport: return "sportscourt"
        }
    }
}

nonisolated struct VeyraPulseInfo: Sendable, Equatable {
    let kind: VeyraPulseKind
    let text: String

    init?(kind: VeyraPulseKind, text: String?) {
        guard let text, !text.isEmpty else { return nil }
        self.kind = kind
        self.text = text
    }
}


/// Icoon + tekst in een glazen pil — dezelfde vulling/rand als de trendlabel-/genre-badges op
/// `VeyraPosterCard`, zodat Pulse er als hetzelfde ontwerpsysteem uitziet.
struct VeyraPulseBadge: View {
    let info: VeyraPulseInfo
    var compact = false
    /// Overschrijft `fontSize` voor contexten die iets meer leesbaarheid nodig hebben dan de
    /// standaard compacte maat (bv. "Live nu" op iPhone/iPad) -- zonder de compacte maat overal
    /// elders (filmkaarten, series) mee te veranderen. `nil` = ongewijzigd bestaand gedrag.
    var fontSizeOverride: CGFloat? = nil

    // Zit in een krappe onderschriftregel (tvOS: 42pt hoog, naast clearlogo) -- daarom bewust
    // weinig verticale opvulling: die ging voorheen ten koste van de leesbare teksthoogte,
    // waardoor de pil kleiner oogde dan de platte tekst die ze verving.
    private var fontSize: CGFloat { fontSizeOverride ?? (compact ? 13 : 23) }
    private var iconFontSize: CGFloat { compact ? 12 : 20 }
    private var hPadding: CGFloat { compact ? 7 : 12 }
    private var vPadding: CGFloat { compact ? 2 : 3 }

    var body: some View {
        HStack(spacing: compact ? 4 : 8) {
            Image(systemName: info.kind.symbol)
                .font(.system(size: iconFontSize, weight: .bold))
                .foregroundStyle(VeyraHomeStyle.cyan)
            Text(info.text)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
        .background(VeyraHomeStyle.cyan.opacity(0.16), in: Capsule())
        .overlay(Capsule().strokeBorder(VeyraHomeStyle.cyan.opacity(0.55), lineWidth: 1.25))
    }
}
