import SwiftUI

/// iOS-native "Sport"-tab. Hergebruikt dezelfde Shared `SportsStore`/
/// `SportsModels` als tvOS' Sportcentrum (`SportsView` in
/// `Veyra/App/tvOS/Sports/SportsViews.swift`), met een eenvoudige native
/// iOS-lijst i.p.v. de tvOS-focuservaring: dagnavigatie, filter op
/// live/programma/uitslagen, favorieten en groepering per competitie.
struct SportsView: View {
    // Zelfde gedeelde `VeyraSportViewModel`/cache als de Home-sectie "Sport" -- geen tweede fetch
    // (spec §4/§57). Teams/competities komen rechtstreeks uit de bestaande `SportsFavorites`/
    // `SportsDisplayPreferences`, geen nieuw favorieten-systeem.
    private var sportModel: VeyraSportViewModel { VeyraBentoServices.shared.sport }

    @State private var now = Date()
    @State private var favoriteTeams: [StoredFavoriteTeam] = []
    @State private var favoriteLeagues: [SportsLeague] = []
    @State private var sportQuery: SportChannelQuery?
    @State private var activeSportEvent: SportEvent?
    @State private var bentoChannel: PlayableSource?
    @State private var showSettings = false
    @State private var selectedTeam: StoredFavoriteTeam?
    @State private var selectedLeague: SportsLeague?

    var body: some View {
        NavigationStack {
            VeyraSportsHome(
                sportModel: sportModel,
                now: now,
                favoriteTeams: favoriteTeams,
                favoriteLeagues: favoriteLeagues,
                onPlay: { event in activeSportEvent = event; sportQuery = SportChannelQuery(event: event) },
                onSelectTeam: { selectedTeam = $0 },
                onSelectLeague: { selectedLeague = $0 },
                onOpenSettings: { showSettings = true }
            )
            .veyraHideNavigationBar()
            .sportChannelSheet($sportQuery) { bentoChannel = $0 }
            .navigationDestination(item: $bentoChannel) { source in
                #if os(iOS)
                PlayerView(source: source, item: MediaItem(title: source.name, type: .liveTV), sportEvent: activeSportEvent)
                #else
                PlayerView(source: source, item: MediaItem(title: source.name, type: .liveTV))
                #endif
            }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(item: $selectedTeam) { team in
                VeyraSportsTeamDetailView(team: team, sportModel: sportModel, now: now) { event in
                    activeSportEvent = event; sportQuery = SportChannelQuery(event: event)
                }
            }
            .navigationDestination(item: $selectedLeague) { league in
                VeyraSportsLeagueDetailView(league: league, sportModel: sportModel, now: now) { event in
                    activeSportEvent = event; sportQuery = SportChannelQuery(event: event)
                }
            }
        }
        .task {
            reloadPreferences()
            if sportModel.phase == .idle { await sportModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            reloadPreferences()
        }
        .task {
            // Klok + live stand periodiek verversen zolang het tabblad open is (zelfde ritme als Home).
            while !Task.isCancelled {
                now = Date()
                await sportModel.reload()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
    }

    /// Herleest favoriete teams + aangezette competities -- reageert zo automatisch op wijzigingen
    /// in Instellingen zonder herstart (spec §35).
    private func reloadPreferences() {
        let ids = SportsFavorites.ids()
        let info = SportsFavorites.info()
        favoriteTeams = ids.compactMap { info[$0] }.sorted { $0.name < $1.name }
        favoriteLeagues = SportsLeague.all.filter { SportsDisplayPreferences.isLeagueEnabled($0.id) }
    }
}

private enum SportsFilterIOS: String, CaseIterable, Identifiable {
    case all = "Alles"
    case live = "Live"
    case upcoming = "Programma"
    case results = "Uitslagen"

    var id: String { rawValue }

    func accepts(_ match: SportsMatch) -> Bool {
        switch self {
        case .all: return true
        case .live: return match.phase == .live
        case .upcoming: return match.phase == .scheduled
        case .results: return match.phase == .finished
        }
    }
}

private struct SportsMatchRowIOS: View {
    let match: SportsMatch
    let homeFavorite: Bool
    let awayFavorite: Bool
    let stale: Bool
    let onToggleHome: () -> Void
    let onToggleAway: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                teamRow(match.home, score: match.homeScore, favorite: homeFavorite, onToggle: onToggleHome)
                teamRow(match.away, score: match.awayScore, favorite: awayFavorite, onToggle: onToggleAway)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if match.phase == .live {
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(VeyraColors.red)
                }

                Text(match.status)
                    .font(.caption2)
                    .foregroundStyle(stale ? .orange : .secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(12)
        .veyraGlass(radius: 14)
    }

    private func teamRow(_ team: SportsTeam, score: String?, favorite: Bool, onToggle: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: favorite ? "star.fill" : "star")
                    .font(.body)
                    .foregroundStyle(favorite ? .yellow : .secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favorite ? "Verwijder uit favoriete teams" : "Maak favoriet team")

            AsyncImage(url: team.logoURL ?? SportsTeam.fallbackLogoURL(abbreviation: team.abbreviation)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Image(systemName: "sportscourt")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 22, height: 22)

            Text(team.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if match.showsScore, let score {
                Text(score)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
    }
}

#Preview {
    SportsView()
}
