// VeyraSportsHome.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Root-view van de herontworpen Sport-tab (spec §5/§68, fase 3-7 samengevoegd). Bouwt uitsluitend
// verder op bestaande data (`SportsFavorites`, `SportsDisplayPreferences`, `VeyraSportViewModel`) --
// GEEN nieuw favorieten-systeem. Toont enkel secties waarvoor content bestaat (spec §5); zonder
// gekozen teams/competities toont dit compacte onboarding i.p.v. een lege/foutmelding-achtige
// ervaring (spec §34). Ontbreken vandaag/binnenkort wedstrijden van gekozen teams: de team-tiles
// blijven gewoon staan (spec §33) -- die sectie hangt niet af van wedstrijddata.

import SwiftUI

struct VeyraSportsHome: View {
    let sportModel: VeyraSportViewModel
    let now: Date
    let favoriteTeams: [StoredFavoriteTeam]
    let favoriteLeagues: [SportsLeague]
    let onPlay: (SportEvent) -> Void
    let onSelectTeam: (StoredFavoriteTeam) -> Void
    let onSelectLeague: (SportsLeague) -> Void
    let onOpenSettings: () -> Void

    private var favoriteTeamIDs: Set<String> { Set(favoriteTeams.map(\.id)) }
    private var favoriteLeagueNames: Set<String> { Set(favoriteLeagues.map(\.name)) }
    private var hasPersonalContent: Bool { !favoriteTeams.isEmpty || !favoriteLeagues.isEmpty }

    /// Alles wat niet al bij "Live voor jou"/"Vandaag"/"Binnenkort" hoort -- overige aangezette sport,
    /// pas ná de persoonlijke content getoond (spec §32).
    private var discoverEvents: [SportEvent] {
        let personal = Set(
            sportModel.liveForYou(at: now, favoriteTeamIDs: favoriteTeamIDs, favoriteLeagueNames: favoriteLeagueNames).map(\.id)
                + sportModel.today(at: now, favoriteTeamIDs: favoriteTeamIDs, favoriteLeagueNames: favoriteLeagueNames).map(\.id)
                + sportModel.upcoming(at: now, favoriteTeamIDs: favoriteTeamIDs, favoriteLeagueNames: favoriteLeagueNames).map(\.id)
        )
        return sportModel.fixtures(at: now, limit: 16).filter { !personal.contains($0.id) }
    }

    var body: some View {
        VeyraDynamicBackgroundScope {
            VeyraScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    header

                    if hasPersonalContent {
                        if !favoriteTeams.isEmpty {
                            VeyraSportsTeamStrip(teams: favoriteTeams, sportModel: sportModel, now: now, onSelect: onSelectTeam)
                        }
                        if !favoriteLeagues.isEmpty {
                            VeyraSportsLeagueStrip(leagues: favoriteLeagues, sportModel: sportModel, now: now, onSelect: onSelectLeague)
                        }

                        let live = sportModel.liveForYou(at: now, favoriteTeamIDs: favoriteTeamIDs, favoriteLeagueNames: favoriteLeagueNames)
                        VeyraSportsLiveStage(events: live, now: now, onPlay: onPlay)

                        let today = sportModel.today(at: now, favoriteTeamIDs: favoriteTeamIDs, favoriteLeagueNames: favoriteLeagueNames)
                        VeyraSportsTodayTimeline(events: today, now: now, onSelect: onPlay)

                        let upcoming = sportModel.upcoming(at: now, favoriteTeamIDs: favoriteTeamIDs, favoriteLeagueNames: favoriteLeagueNames)
                        VeyraSportsUpcomingSection(events: upcoming, now: now, onSelect: onPlay)
                    } else {
                        onboarding
                    }

                    discoverMore
                }
                .padding(.horizontal, sidePadding)
                .padding(.vertical, 24)
            }
            .background(VeyraBackground())
            #if os(tvOS)
            .scrollClipDisabled()
            #endif

        }
    }

    // MARK: - Header (spec §6: compacte identity header, geen filmhero, geen dubbele navigation)

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(VeyraColors.cyan).frame(width: 7, height: 7)
                Text("Veyra Sport")
                    .font(.system(size: eyebrowSize, weight: .bold))
                    .tracking(2)
                    .textCase(.uppercase)
            }
            .foregroundStyle(VeyraColors.cyan.opacity(0.9))

            Text("Sport")
                .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Rectangle()
                .fill(VeyraColors.cyan.opacity(0.7))
                .frame(width: underlineWidth, height: 3)
                .clipShape(Capsule())
        }
    }

    // MARK: - Onboarding (spec §34)

    private var onboarding: some View {
        VStack(spacing: 14) {
            Text("Maak Sport persoonlijk")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text("Kies je favoriete teams en competities in Instellingen.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("Open instellingen", action: onOpenSettings)
                #if os(tvOS)
                .buttonStyle(VeyraSportCardStyle(isLive: false))
                #endif
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(VeyraColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Ontdek meer (spec §32: pas na persoonlijke content, hergebruikt bestaande VeyraSportMatchCard)

    @ViewBuilder
    private var discoverMore: some View {
        if !discoverEvents.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Ontdek meer")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.5))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(discoverEvents) { event in
                            Button { onPlay(event) } label: {
                                VeyraSportMatchCard(event: event, now: now, reminderOn: false)
                            }
                            #if os(tvOS)
                            .buttonStyle(VeyraSportCardStyle(isLive: event.isLive(at: now)))
                            #else
                            .buttonStyle(.plain)
                            #endif
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            }
        }
    }

    #if os(tvOS)
    private let titleSize: CGFloat = 40
    private let eyebrowSize: CGFloat = 16
    private let sectionSpacing: CGFloat = 36
    private let sidePadding: CGFloat = 60
    private let underlineWidth: CGFloat = 48
    #else
    private let titleSize: CGFloat = 28
    private let eyebrowSize: CGFloat = 12
    private let sectionSpacing: CGFloat = 28
    private let sidePadding: CGFloat = 16
    private let underlineWidth: CGFloat = 32
    #endif
}
