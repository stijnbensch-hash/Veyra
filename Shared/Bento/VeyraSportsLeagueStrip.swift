// VeyraSportsLeagueStrip.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Jouw Competities" -- tweede persoonlijke sectie van de Sport-redesign (spec §11/12, fase 4).
// GEEN nieuwe favorieten-store voor leagues: de app heeft geen apart "favoriete competities"-
// mechanisme (enkel `SportsFavorites` voor TEAMS). In plaats daarvan wordt de bestaande
// zichtbaarheids-voorkeur (`SportsDisplayPreferences`, Instellingen > Sport) gebruikt als
// "mijn competities" -- wat je aangezet hebt is wat je volgt. Standaard staat alles aan, dus
// zonder een bewuste keuze toont dit gewoon alle ondersteunde competities (bestaand gedrag,
// geen regressie). Logo per competitie komt uit `VeyraSportViewModel.competitions(at:)`
// (al bestaand, geen nieuwe fetch).

import SwiftUI

struct VeyraSportsLeagueStrip: View {
    let leagues: [SportsLeague]
    let sportModel: VeyraSportViewModel
    let now: Date
    let onSelect: (SportsLeague) -> Void

    private var logosByName: [String: URL] {
        Dictionary(sportModel.competitions(at: now).compactMap { c in c.logoURL.map { (c.name, $0) } },
                  uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        if !leagues.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text("Jouw competities")
                        .font(.system(size: headerSize, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))
                    VeyraSectionTitleLine()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: cardGap) {
                        ForEach(leagues) { league in
                            tile(league)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 12)
                }
                .scrollClipDisabled()
            }
        }
    }

    @ViewBuilder
    private func tile(_ league: SportsLeague) -> some View {
        Button { onSelect(league) } label: {
            LeagueTileContent(league: league, logoURL: league.logoURL ?? logosByName[league.name], width: tileWidth, height: tileHeight)
        }
        #if os(tvOS)
        .buttonStyle(VeyraStreamingTileStyle())
        #else
        .buttonStyle(.plain)
        #endif
    }

    #if os(tvOS)
    private let headerSize: CGFloat = 21
    private let cardGap: CGFloat = 24
    private let tileWidth: CGFloat = 260
    private let tileHeight: CGFloat = 160
    #else
    private let headerSize: CGFloat = 14
    private let cardGap: CGFloat = 14
    private let tileWidth: CGFloat = 150
    private let tileHeight: CGFloat = 98
    #endif
}

private struct LeagueTileContent: View {
    let league: SportsLeague
    let logoURL: URL?
    let width: CGFloat
    let height: CGFloat

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(spacing: 8) {
            VeyraAsyncImage(url: logoURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: league.symbol)
                        .resizable().scaledToFit()
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(logoSize * 0.22)
                }
            }
            // Bredere (i.p.v. vierkante) begrenzing: brede logo-lockups (bv. "Belgische Pro
            // League", liggend) krijgen zo evenveel ruimte als vierkante/staande competitielogo's
            // i.p.v. dat scaledToFit ze binnen een vierkant kleiner maakt dan de rest.
            .frame(width: logoSize * 1.7, height: logoSize)

            Text(league.name)
                .font(.system(size: nameSize, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: height)
        // Dark glass, geen league-brandkleur als achtergrond (spec §12).
        .background(.white.opacity(isFocused ? 0.08 : 0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isFocused ? VeyraColors.cyan.opacity(0.6) : .white.opacity(0.08),
                             lineWidth: isFocused ? 2 : 1)
        )
        .scaleEffect(isFocused ? 1.05 : 1)
        .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.28) : .clear, radius: 18)
        .animation(.easeOut(duration: 0.16), value: isFocused)
    }

    private var logoSize: CGFloat { height * 0.5 }
    private var nameSize: CGFloat { width > 200 ? 17 : 13 }
}
