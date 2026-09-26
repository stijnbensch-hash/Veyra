// VeyraSportMatchCard.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Compacte wedstrijdkaart voor de nieuwe Sport-sectie ("Mijn teams" + per-competitie), naar het
// voorbeeld van een "gidsachtige" sport-widget: klok+tijdstip linksboven, de twee teams
// (rond logo + naam) daaronder gestapeld, en onderaan een sport-icoon + competitie-label in
// kleine kapitalen. Lichte, halfdoorzichtige achtergrond, afgeronde hoeken, vierkant-achtig
// (i.p.v. de brede "Vandaag & straks"-rij die VeyraFixtureRowContent gebruikt).
//
// iOS/macOS: zie VeyraBentoSportSectionIOS.swift voor waar deze kaart in een 2-/4-koloms grid
// gebruikt wordt (`Button { ... } label: { VeyraSportMatchCard(...) }.buttonStyle(VeyraPressStyle(...))`).
// tvOS: zie VeyraBentoSportSection.swift -- daar wordt dezelfde kaart, met grotere 10-foot-maten,
// als focusbare knop gebruikt (`.buttonStyle(VeyraSportCardStyle(isLive:))`, `.focused(focus, equals: .sport(section:, id:))`).
// De maten hieronder splitsen per platform via `#if os(tvOS)`; de kaart zelf tekent geen eigen
// focus-rand op tvOS -- dat blijft de taak van de omliggende ButtonStyle, net als bij de andere
// tvOS sport-content-views in VeyraBentoSportViews.swift.

import SwiftUI

struct VeyraSportMatchCard: View {
    let event: SportEvent
    let now: Date
    let reminderOn: Bool

    private var live: Bool { event.isLive(at: now) }

    #if os(tvOS)
    // 10-foot-maten: logo's en tekst merkbaar groter (+ ~55%) voor leesbaarheid vanaf de zithoek;
    // de kaart zelf (breedte/hoogte/padding) is evenredig meegegroeid zodat niets knijpt. Deze rij
    // is zelf-sizing (geen vaste rij-hoogte in VeyraBentoSportSection.swift), dus een grotere kaart
    // hier is voldoende -- er is geen apart hoogte-getal om mee te schalen.
    private let padding: CGFloat = 20
    private let outerSpacing: CGFloat = 14
    private let rowSpacing: CGFloat = 10
    private let badgeSize: CGFloat = 68
    private let cornerRadius: CGFloat = 22
    private let minHeight: CGFloat = 230
    private let cardWidth: CGFloat = 470
    private let headerFont: CGFloat = 30
    private let headerIconFont: CGFloat = 24
    private let teamFont: CGFloat = 24
    private let initialsFont: CGFloat = 22
    private let footerFont: CGFloat = 16
    private let footerIconFont: CGFloat = 22
    #else
    private let padding: CGFloat = 12
    private let outerSpacing: CGFloat = 10
    private let rowSpacing: CGFloat = 7
    private let badgeSize: CGFloat = 30
    private let cornerRadius: CGFloat = 16
    private let minHeight: CGFloat = 128
    private let cardWidth: CGFloat? = nil
    private let headerFont: CGFloat = 13
    private let headerIconFont: CGFloat = 11
    private let teamFont: CGFloat = 13
    private let initialsFont: CGFloat = 9
    private let footerFont: CGFloat = 10
    private let footerIconFont: CGFloat = 10
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: outerSpacing) {
            header
            VStack(alignment: .leading, spacing: rowSpacing) {
                teamRow(event.home, logo: event.homeLogoURL)
                teamRow(event.away, logo: event.awayLogoURL)
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: minHeight)
        #if os(tvOS)
        .frame(width: cardWidth)
        #endif
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(live ? VeyraHomeStyle.live.opacity(0.16) : VeyraHomeStyle.cyan.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(live ? VeyraHomeStyle.live.opacity(0.4) : VeyraHomeStyle.cyan.opacity(0.45), lineWidth: 1)
        )
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: Kop: klok + tijdstip (of live-status)

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 6) {
            if live {
                Circle().fill(VeyraHomeStyle.live).frame(width: badgeIndicatorSize, height: badgeIndicatorSize)
                Text(event.score?.text ?? event.score?.minute ?? "LIVE")
                    .font(.system(size: headerFont, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(VeyraHomeStyle.live)
            } else {
                Image(systemName: "clock")
                    .font(.system(size: headerIconFont, weight: .semibold))
                    .foregroundStyle(VeyraHomeStyle.cyan)
                Text(event.start.formatted(.dateTime.hour().minute().locale(VeyraHomeFormat.locale)))
                    .font(.system(size: headerFont, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(VeyraHomeStyle.cyan)
                if !Calendar.current.isDate(event.start, inSameDayAs: now) {
                    Text(event.start.formatted(.dateTime.weekday(.abbreviated).locale(VeyraHomeFormat.locale)))
                        .font(.system(size: headerIconFont, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(VeyraHomeStyle.cyan)
                }
            }
            Spacer(minLength: 4)
            if let tvBroadcast = event.tvBroadcast, !tvBroadcast.isEmpty {
                Text(tvBroadcast)
                    .font(.system(size: headerIconFont, weight: .bold))
                    .foregroundStyle(VeyraHomeStyle.live)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var badgeIndicatorSize: CGFloat {
        #if os(tvOS)
        return 15
        #else
        return 6
        #endif
    }

    // MARK: Team-rij: rond logo + naam

    private func teamRow(_ name: String?, logo: URL?) -> some View {
        let displayName = name ?? event.title
        return HStack(spacing: rowSpacing) {
            teamBadge(logo, name: displayName)
            Text(displayName)
                .font(.system(size: teamFont, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
    }

    private func teamBadge(_ url: URL?, name: String) -> some View {
        ZStack {
            // Puur het logo, zonder eigen achtergrondvorm op elk platform -- alleen de tekst-fallback
            // (geen logo-URL, of de AsyncImage-fase mislukt) krijgt nog een subtiel rond vlak zodat de
            // initialen leesbaar blijven.
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        fallbackInitials(name)
                    }
                }
            } else {
                fallbackInitials(name)
            }
        }
        .frame(width: badgeSize, height: badgeSize)
    }

    @ViewBuilder
    private func fallbackInitials(_ name: String) -> some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.14))
            Text(VeyraSportFormat.initials(name))
                .font(.system(size: initialsFont, weight: .heavy))
        }
    }

    // MARK: Voet: sport-icoon + competitie in kleine kapitalen

    private var footer: some View {
        HStack(spacing: 6) {
            if let symbol = event.leagueSymbol {
                Image(systemName: symbol)
                    .font(.system(size: footerIconFont, weight: .semibold))
            }
            if let competition = event.competition, !competition.isEmpty {
                Text(competition)
                    .font(.system(size: footerFont, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !live {
                Image(systemName: reminderOn ? "bell.fill" : "bell")
                    .font(.system(size: footerIconFont, weight: .semibold))
                    .foregroundStyle(reminderOn ? VeyraHomeStyle.cyan : VeyraHomeStyle.dim)
            }
        }
        .foregroundStyle(VeyraHomeStyle.dim)
    }

    private var accessibilityText: String {
        let broadcast = event.tvBroadcast.map { ", op \($0)" } ?? ""
        if live {
            let score = event.score.map { ", stand \($0.home) \($0.away)" } ?? ""
            return "Live: \(event.title)\(score)\(broadcast)"
        }
        return "\(event.title), \(VeyraSportFormat.kickoff(event.start, now: now))\(broadcast)"
    }
}
