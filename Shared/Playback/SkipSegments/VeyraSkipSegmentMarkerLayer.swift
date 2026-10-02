// VeyraSkipSegmentMarkerLayer.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Marker-laag voor skip-segmenten bovenop de bestaande Player-progressbar (spec "Veyra Player —
// skip segments op bestaande progressbar" §4/§6/§15/§26).
// Tekent GEEN eigen geometry/track -- gebruikt exact de trackbreedte die de aanroepende
// progressbar al berekent, en kent zelf geen enkele bron (enkel `segment.type`/`start`/`end`,
// spec §7: "geen IntroDB/SkipDB-specifieke code in de progressbar").
//
// Update (duidelijkere markers): i.p.v. een dunne, subtiele capsule-range tekent deze laag nu
// een verticale streep exact op het beginpunt en exact op het eindpunt van elk segment, die
// zichtbaar "doorheen" de progressbar-track loopt (boven én onder de track uitstekend) i.p.v.
// er enkel boven te zweven. Een zeer lichte vulling tussen beide strepen blijft de range
// leesbaar maken, maar de strepen zelf zijn het primaire signaal.

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
    /// Hoogte van de onderliggende progressbar-track -- bepaalt hoe ver de begin/eind-strepen
    /// boven en onder de track uitsteken, zodat ze er duidelijk "doorheen" lopen.
    let trackHeight: CGFloat
    /// Werkelijke afspeeltijd (spec §28/§29: zelfde currentTime-bron als skip-knop/Next Up,
    /// geen eigen afwijkend algoritme) -- bepaalt per marker of hij "actief" getekend wordt.
    let currentTime: TimeInterval

    /// Hoeveel de verticale streep boven/onder de track uitsteekt.
    private static let overshoot: CGFloat = 5
    private static let lineWidth: CGFloat = 2
    private static let activeLineWidth: CGFloat = 2.6
    private static let activeOpacity: Double = 0.95
    /// Zeer lichte vulling tussen begin- en eindstreep, enkel om de range leesbaar te maken --
    /// de verticale strepen aan begin/eind blijven het primaire signaal.
    private static let rangeFillOpacity: Double = 0.14

    /// Basis-opacity per type (hoofdzakelijk cyaan, Recap/Preview iets gedimd).
    private static func baseOpacity(for type: VeyraSkipSegmentType) -> Double {
        switch type {
        case .recap: return 0.45
        case .preview: return 0.5
        case .intro, .credits, .commercial: return 0.65
        }
    }

    /// Credits krijgt een rood accent (consistent met "rood = reeds afgespeeld" elders in de
    /// bar), alle andere types blijven cyaan.
    private func lineColor(for type: VeyraSkipSegmentType) -> Color {
        type == .credits ? VeyraColors.red : VeyraColors.cyan
    }

    var body: some View {
        let lineHeight = trackHeight + Self.overshoot * 2
        ZStack(alignment: .topLeading) {
            ForEach(segments) { segment in
                if let fraction = segment.markerFraction(duration: duration) {
                    let isActive = segment.contains(currentTime)
                    let color = lineColor(for: segment.type)
                    let width = max(0, trackWidth * CGFloat(fraction.width))
                    let startX = trackWidth * CGFloat(fraction.start)
                    let opacity = isActive ? Self.activeOpacity : Self.baseOpacity(for: segment.type)
                    let thickness = isActive ? Self.activeLineWidth : Self.lineWidth

                    // Zachte vulling tussen begin en eind, enkel leesbaarheid -- geen vervanging
                    // van de strepen.
                    Rectangle()
                        .fill(color.opacity(Self.rangeFillOpacity))
                        .frame(width: width, height: trackHeight)
                        .offset(x: startX)

                    // Beginstreep -- loopt zichtbaar doorheen de track.
                    Rectangle()
                        .fill(color.opacity(opacity))
                        .frame(width: thickness, height: lineHeight)
                        .shadow(color: color.opacity(isActive ? 0.5 : 0), radius: isActive ? 3 : 0)
                        .offset(x: startX - thickness / 2, y: -Self.overshoot)

                    // Eindstreep -- loopt zichtbaar doorheen de track.
                    Rectangle()
                        .fill(color.opacity(opacity))
                        .frame(width: thickness, height: lineHeight)
                        .shadow(color: color.opacity(isActive ? 0.5 : 0), radius: isActive ? 3 : 0)
                        .offset(x: startX + width - thickness / 2, y: -Self.overshoot)
                }
            }
        }
        // Spec §26: markers zijn niet interactief, seekbar blijft eigenaar van input.
        .allowsHitTesting(false)
    }
}
