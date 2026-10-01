// VeyraSportsStage.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Live Match Stage": een uitgelichte kaart voor de op dit moment live wedstrijd,
// uit het Home Visual System-spec (Stap 14) -- sport moet er visueel TOTAAL anders
// uitzien dan films: geen poster-rail, wel team-logo's, stand, competitie, live-status
// en tijd op de voorgrond (spec §51/§53). Dit vult de bestaande Sport-sectie aan
// (`SportSection`, met haar eigen lijst/competities/herinneringen, ongewijzigd) met
// precies één uitgelichte kaart wanneer er nu een live wedstrijd is.
// "● LIVE" blijft een klein, rood label -- geen volledig rode kaart (spec §54).
// Data: bestaande `SportEvent`/`SportScore` (`sportModel.liveEvents`) -- geen nieuwe bron.

import SwiftUI

struct VeyraSportsStage: View {
    let event: SportEvent
    let now: Date
    let onPlay: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: onPlay) {
            content
        }
        #if os(tvOS)
        .buttonStyle(VeyraStreamingTileStyle())
        #else
        .buttonStyle(.plain)
        #endif
    }

    /// Eerst het curated competitie-logo (Wikipedia, via `SportsLeague.logoURL`) -- vooral voor
    /// college-football-conferences geeft ESPN zelf vaak geen (of een generiek) logo terug.
    /// Alleen als die competitie niet in `SportsLeague.all` voorkomt, terugvallen op ESPN's eigen
    /// `event.leagueLogoURL`.
    private var leagueLogoURL: URL? {
        SportsLeague.logo(forCompetition: event.competition, fallback: event.leagueLogoURL)
    }

    private var content: some View {
        ZStack {
            // Competitielogo als zacht watermerk, geen filmposter-achtige achtergrond
            // (spec §53: "Niet: movie poster style").
            if let leagueLogoURL {
                // Zonder expliciete maat neemt een resizable AsyncImage in een ZStack zonder
                // omringende breedte-/hoogtebeperking (bv. in een vrij scrollende detailview,
                // i.p.v. de Bento-grid op Home) de volledige beschikbare ruimte in -- de hele
                // kaart blies daardoor op. Vaste max-maat houdt dit overal een zacht watermerk.
                AsyncImage(url: leagueLogoURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                            .opacity(0.08)
                    }
                }
                .frame(maxWidth: watermarkMaxSize, maxHeight: watermarkMaxSize)
                .padding(40)
            }

            VStack(spacing: rowSpacing) {
                if let competition = event.competition, !competition.isEmpty {
                    Text(competition.uppercased())
                        .font(.system(size: competitionSize, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.65))
                }

                // "LIVE" alleen echt tonen als de wedstrijd nu ook werkelijk bezig is (spec §54) --
                // deze kaart wordt niet enkel voor live wedstrijden hergebruikt (bv. de eerstvolgende
                // wedstrijd in een teamdetail), dus zonder deze check stond er een onterecht "LIVE".
                if isLive {
                    HStack(spacing: 6) {
                        Circle().fill(VeyraColors.red).frame(width: 7, height: 7)
                        Text(liveLabel)
                            .font(.system(size: liveSize, weight: .heavy))
                            .monospacedDigit()
                    }
                    .foregroundStyle(VeyraColors.red)
                } else if isPast {
                    Text("AFGELOPEN")
                        .font(.system(size: liveSize, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    Text(VeyraHomeFormat.when(event.start, now: now))
                        .font(.system(size: liveSize, weight: .heavy))
                        .foregroundStyle(VeyraColors.cyan)
                }

                HStack(alignment: .center, spacing: scoreGap) {
                    teamBadge(event.home, logo: event.homeLogoURL)
                    Text(event.score?.text ?? "vs")
                        .font(.system(size: scoreSize, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(event.score != nil ? .white : .white.opacity(0.4))
                        .frame(minWidth: scoreMinWidth)
                    teamBadge(event.away, logo: event.awayLogoURL)
                }

                Text(event.channelName)
                    .font(.system(size: footerSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.vertical, paddingV)
            .padding(.horizontal, paddingH)
        }
        .frame(maxWidth: .infinity)
        .background(VeyraColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        // Zelfde cyaan/rode Veyra-kaderstijl als de rest van Home (VeyraFrame): in rust een
        // subtiele cyaan-naar-rood gradiëntrand, bij focus feller cyaan (focus is altijd cyaan).
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(isFocused ? VeyraFrame.active : VeyraFrame.resting,
                              lineWidth: isFocused ? 2.5 : 1.5)
        )
        // Zelfde focus-gloed als de andere nieuwe secties (Discovery Flow/On Air/
        // Top 10 Orbit): lichte opschaling + cyaan schaduw bij focus (Stap 18,
        // visual consistency pass -- zonder dit had deze kaart als enige geen
        // zichtbare focus-status op tvOS).
        .scaleEffect(isFocused ? 1.02 : 1)
        .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.28) : .clear, radius: 20)
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }

    private var isLive: Bool { event.isLive(at: now) }
    private var isPast: Bool { event.isPast(at: now) }

    private var liveLabel: String {
        if let minute = event.score?.minute, !minute.isEmpty { return "LIVE · \(minute)" }
        return "LIVE"
    }

    private func teamBadge(_ name: String?, logo: URL?) -> some View {
        VStack(spacing: 8) {
            AsyncImage(url: logo) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Color.white.opacity(0.1)
                }
            }
            .frame(width: badgeSize, height: badgeSize)
            .clipShape(Circle())
            // Volledige teamnaam i.p.v. afgekapt -- twee regels toegestaan en een bredere
            // kolom (was 1.6x badgeSize/1 regel, te smal voor langere teamnamen).
            Text(name ?? "")
                .font(.system(size: teamSize, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.65)
                .frame(width: badgeSize * 2.2)
        }
    }

    // Maten -- tvOS 10-voet-UI, iOS/iPadOS/macOS compacter van dichtbij bekeken.
    #if os(tvOS)
    private let rowSpacing: CGFloat = 14
    private let competitionSize: CGFloat = 18
    private let liveSize: CGFloat = 22
    private let scoreSize: CGFloat = 56
    private let scoreMinWidth: CGFloat = 140
    private let scoreGap: CGFloat = 40
    private let badgeSize: CGFloat = 84
    private let teamSize: CGFloat = 22
    private let footerSize: CGFloat = 17
    private let watermarkMaxSize: CGFloat = 220
    private let paddingV: CGFloat = 32
    private let paddingH: CGFloat = 40
    #else
    private let rowSpacing: CGFloat = 10
    private let competitionSize: CGFloat = 12
    private let liveSize: CGFloat = 14
    private let scoreSize: CGFloat = 32
    private let scoreMinWidth: CGFloat = 80
    private let scoreGap: CGFloat = 24
    private let badgeSize: CGFloat = 48
    private let teamSize: CGFloat = 13
    private let footerSize: CGFloat = 12
    private let watermarkMaxSize: CGFloat = 140
    private let paddingV: CGFloat = 20
    private let paddingH: CGFloat = 20
    #endif
}
