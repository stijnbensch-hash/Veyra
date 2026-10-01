// VeyraSkipSegmentMarkerLayer.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Dunne, niet-interactieve marker-laag voor skip-segmenten bovenop de bestaande Player-
// progressbar (spec "Veyra Player — skip segments op bestaande progressbar" §4/§6/§15/§26).
// Tekent GEEN eigen geometry/track -- gebruikt exact de trackbreedte die de aanroepende
// progressbar al berekent, en kent zelf geen enkele bron (enkel `segment.type`/`start`/`end`,
// spec §7: "geen IntroDB/SkipDB-specifieke code in de progressbar").
//
// Fase 3: enkel eenvoudige dunne ranges, geen labels/glow/actieve-staat-polish (die volgen in
// Fase 4/5).

import SwiftUI

extension VeyraSkipSegment {
    /// Horizontale positie/breedte van deze marker als fractie van de totale trackbreedte
    /// (spec §16). `nil` als de duur ongeldig is of het segment geen zinvolle zichtbare range
    /// oplevert (spec §17/§19) -- renderen dan gewoon niets, geen gegokte waarden.
    func markerFraction(duration: TimeInterval) -> (start: Double, width: Double)? {
        guard duration.isFinite, duration > 0 else { return nil }
        let effectiveStart = max(0, min(duration, start ?? 0))
        let effectiveEnd = max(0, min(duration, end ?? duration))
        guard effectiveEnd > effectiveStart else { return nil }
        return (effectiveStart / duration, (effectiveEnd - effectiveStart) / duration)
    }
}

struct VeyraSkipSegmentMarkerLayer: View {
    let segments: [VeyraSkipSegment]
    let duration: TimeInterval
    let trackWidth: CGFloat
    /// Werkelijke afspeeltijd (spec §28/§29: zelfde currentTime-bron als skip-knop/Next Up,
    /// geen eigen afwijkend algoritme) -- bepaalt per marker of hij "actief" getekend wordt.
    let currentTime: TimeInterval

    /// Minimale zichtbare breedte (spec §20) -- verandert nooit segment.start/segment.end zelf,
    /// enkel de rendering van extreem korte segmenten.
    private static let minimumVisibleWidth: CGFloat = 3
    private static let activeOpacity: Double = 0.85
    private static let inactiveHeight: CGFloat = 3
    private static let activeHeight: CGFloat = 4
    /// Zeer klein rood Veyra-accentje aan het einde van een Credits-marker (spec §9/§10) --
    /// nooit een volledig rode range, dat zou botsen met "rood = reeds afgespeeld".
    private static let creditsAccentWidth: CGFloat = 3

    /// Basis-opacity per type (spec §9: hoofdzakelijk cyaan, Recap lager-opacity, Preview dim).
    private static func baseOpacity(for type: VeyraSkipSegmentType) -> Double {
        switch type {
        case .recap: return 0.22
        case .preview: return 0.28
        case .intro, .credits, .commercial: return 0.38
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(segments) { segment in
                if let fraction = segment.markerFraction(duration: duration) {
                    // Spec §12: subtiel helderder/iets dikker + zeer zachte gloed, geen
                    // pulse/grote animaties.
                    let isActive = segment.contains(currentTime)
                    let width = max(Self.minimumVisibleWidth, trackWidth * CGFloat(fraction.width))
                    let height: CGFloat = isActive ? Self.activeHeight : Self.inactiveHeight

                    Capsule()
                        .fill(VeyraColors.cyan.opacity(isActive ? Self.activeOpacity : Self.baseOpacity(for: segment.type)))
                        .frame(width: width, height: height)
                        .shadow(color: VeyraColors.cyan.opacity(isActive ? 0.45 : 0), radius: isActive ? 4 : 0)
                        .offset(x: trackWidth * CGFloat(fraction.start))

                    // Spec §10: subtiel randje/eindmarkering, geen volledige rode credits-range.
                    if segment.type == .credits {
                        Capsule()
                            .fill(VeyraColors.red.opacity(isActive ? 0.9 : 0.55))
                            .frame(width: Self.creditsAccentWidth, height: height)
                            .offset(
                                x: min(
                                    trackWidth - Self.creditsAccentWidth,
                                    trackWidth * CGFloat(fraction.start) + width - Self.creditsAccentWidth
                                )
                            )
                    }
                }
            }
        }
        // Spec §26: markers zijn niet interactief, seekbar blijft eigenaar van input.
        .allowsHitTesting(false)
    }
}
