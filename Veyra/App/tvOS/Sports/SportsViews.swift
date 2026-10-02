import SwiftUI

private let sportsNavy =
    Color(
        red: 0.015,
        green: 0.045,
        blue: 0.075
    )

// MARK: - Sports Center

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
        .preferredColorScheme(.dark)
        .navigationTitle("")
        .sportChannelSheet($sportQuery) { bentoChannel = $0 }
        .navigationDestination(item: $bentoChannel) { source in
            PlayerView(source: source, item: MediaItem(title: source.name, type: .liveTV), sportEvent: activeSportEvent)
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

// MARK: - Filter

private enum SportsFilter:
    String,
    Identifiable,
    CaseIterable
{
    case all = "Alles"
    case live = "Live"
    case upcoming = "Programma"
    case results = "Uitslagen"

    var id: String {
        rawValue
    }

    func accepts(
        _ match:
            SportsMatch
    ) -> Bool {
        switch self {
        case .all:
            return true

        case .live:
            return
                match.phase == .live

        case .upcoming:
            return
                match.phase == .scheduled
                || match.phase == .postponed

        case .results:
            return
                match.phase == .finished
        }
    }
}

// MARK: - Sports Home

struct SportsHomeView: View {
    @StateObject
    private var store =
        SportsStore()

    @Environment(\.scenePhase)
    private var scenePhase

    @State
    private var selectedMatch:
        SportsMatch?

    @FocusState
    private var focusedMatchID:
        String?

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            VeyraSectionHeader(
                title: "Sport vandaag",
                subtitle: "Programma en uitslagen"
            )

            SportsFeedStatus(
                store: store
            )

            if store.highlights.isEmpty {
                Text(
                    store.isLoading
                        ? "Wedstrijden ophalen…"
                        : store.failedLeagues.isEmpty
                            ? "Vandaag geen wedstrijden in je competities. Bekijk het programma in Sportcentrum."
                            : "Scores tijdelijk niet beschikbaar. Open Sportcentrum om opnieuw te proberen."
                )
                .font(
                    .system(
                        size: 24
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .padding(
                    .vertical,
                    30
                )
            } else {
                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    LazyHStack(
                        spacing: 28
                    ) {
                        ForEach(
                            store.highlights
                        ) { match in
                            homeMatchControl(
                                match
                            )
                        }
                    }
                    .padding(16)
                }
                .scrollClipDisabled()
            }
        }
        .navigationDestination(
            item:
                $selectedMatch
        ) { match in
            SportsMatchView(
                match: match,
                store: store
            )
        }
        .task(id: scenePhase) {
            guard
                scenePhase == .active
            else {
                return
            }

            while !Task.isCancelled {
                await store.refresh(
                    date: Date()
                )

                do {
                    try await Task.sleep(
                        for: .seconds(60)
                    )
                } catch {
                    return
                }
            }
        }
    }

    private func homeMatchControl(
        _ match:
            SportsMatch
    ) -> some View {
        let isFocused =
            focusedMatchID
                == match.id

        return SportsScoreCard(
            match: match,
            favorite:
                store.isFavorite(
                    match
                ),
            stale:
                store.failedLeagues
                    .contains(
                        match.league.id
                    ),
            isFocused:
                isFocused
        )
        .frame(
            width: 410
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .focusable(true)
        .focused(
            $focusedMatchID,
            equals:
                match.id
        )
        .focusEffectDisabled()
        .onTapGesture {
            selectedMatch =
                match
        }
        .contextMenu {
            Button {
                store.toggle(match.home)
            } label: {
                Label(
                    match.home.name,
                    systemImage: store.isFavoriteTeam(match.home) ? "star.fill" : "star"
                )
            }

            Button {
                store.toggle(match.away)
            } label: {
                Label(
                    match.away.name,
                    systemImage: store.isFavoriteTeam(match.away) ? "star.fill" : "star"
                )
            }
        }
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            "\(match.home.name) tegen \(match.away.name)"
        )
        .accessibilityValue(
            match.status
        )
    }
}

// MARK: - Feed Status

private struct SportsFeedStatus:
    View
{
    @ObservedObject
    var store:
        SportsStore

    var body: some View {
        HStack(
            spacing: 12
        ) {
            if store.isLoading {
                ProgressView()
                    .controlSize(
                        .small
                    )
            }

            if !store
                .failedLeagues
                .isEmpty
            {
                Label(
                    "Niet alle scores actueel · probeer Vernieuwen",
                    systemImage:
                        "wifi.exclamationmark"
                )
                .foregroundStyle(
                    .orange
                )
            } else if
                let updated =
                    store.updatedAt
            {
                Text(
                    "Bijgewerkt \(updated.formatted(date: .omitted, time: .shortened)) · ESPN"
                )
            } else {
                Text(
                    "Programma en scores · ESPN"
                )
            }
        }
        .font(
            .system(
                size: 19
            )
        )
        .foregroundStyle(
            .secondary
        )
    }
}

// MARK: - Score Card

private struct SportsScoreCard:
    View
{
    let match:
        SportsMatch

    let favorite:
        Bool

    let stale:
        Bool

    var isFocused =
        false

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            HStack {
                Label(
                    match.league.name,
                    systemImage:
                        match.league.symbol
                )
                .lineLimit(1)
                .minimumScaleFactor(
                    0.8
                )

                Spacer(
                    minLength: 4
                )

                if favorite {
                    Image(
                        systemName:
                            "star.fill"
                    )
                    .foregroundStyle(
                        .cyan
                    )
                }
            }
            .font(
                .system(
                    size: 18,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                .secondary
            )

            teamLine(
                match.home,
                score:
                    match.homeScore
            )

            teamLine(
                match.away,
                score:
                    match.awayScore
            )

            Divider()
                .overlay(
                    .cyan.opacity(
                        0.2
                    )
                )

            Text(
                stale
                    ? "Laatste bekende stand · niet actueel"
                    : match.status
            )
            .font(
                .system(
                    size: 19,
                    weight: .bold
                )
            )
            .foregroundStyle(
                stale
                    ? .orange
                    : match.phase == .live
                        ? .red
                        : .secondary
            )
            .lineLimit(1)
            .minimumScaleFactor(
                0.7
            )
        }
        .padding(26)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: VeyraRadius.card,
                style: .continuous
            )
            .fill(
                isFocused
                    ? VeyraColors.cyan.opacity(0.17)
                    : VeyraColors.surface.opacity(0.76)
            )
        )
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
                cornerRadius: VeyraRadius.card,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: VeyraRadius.card,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                    ? VeyraColors.cyan
                    : VeyraColors.cyan.opacity(
                        match.phase == .live
                            ? 0.65
                            : 0.18
                    ),
                lineWidth:
                    isFocused
                    ? 3
                    : 1
            )
        )
    }

    // MARK: - Team Line

    private func teamLine(
        _ team:
            SportsTeam,
        score:
            String?
    ) -> some View {
        HStack(
            spacing: 14
        ) {
            SportsTeamLogo(
                team: team,
                size: 54
            )

            Text(
                team.name
            )
            .font(
                .system(
                    size: 24,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                .white
            )
            .lineLimit(1)
            .minimumScaleFactor(
                0.70
            )

            Spacer(
                minLength: 4
            )

            Text(
                match.showsScore
                    ? score ?? "–"
                    : "–"
            )
            .font(
                .system(
                    size: 32,
                    weight: .bold,
                    design: .rounded
                )
            )
            .monospacedDigit()
            .foregroundStyle(
                .white
            )
        }
    }
}

// MARK: - Transparent Team Logo

private struct SportsTeamLogo:
    View
{
    let team:
        SportsTeam

    let size:
        CGFloat

    var body: some View {
        ZStack {
            if let logoURL =
                team.logoURL
            {
                VeyraAsyncImage(
                    url: logoURL
                ) { phase in
                    switch phase {
                    case .success(
                        let image
                    ):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(2)

                    case .empty:
                        ProgressView()
                            .scaleEffect(
                                0.65
                            )

                    case .failure:
                        fallback

                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(
            width: size,
            height: size
        )
    }

    private var fallback:
        some View
    {
        Text(
            team.abbreviation
        )
        .font(
            .system(
                size: max(
                    10,
                    size * 0.24
                ),
                weight: .bold
            )
        )
        .foregroundStyle(
            .cyan
        )
        .minimumScaleFactor(
            0.55
        )
        .lineLimit(1)
        .padding(4)
    }
}

// MARK: - Match Detail

private struct SportsMatchView:
    View
{
    let match:
        SportsMatch

    @ObservedObject
    var store:
        SportsStore

    @Environment(\.scenePhase)
    private var scenePhase

    @State
    private var channelQuery: SportChannelQuery?

    @State
    private var playing: PlayableSource?

    private var current:
        SportsMatch
    {
        store.matches.first {
            $0.id == match.id
        }
        ?? match
    }

    var body: some View {
        VStack(
            spacing: 35
        ) {
            Text(
                current.league.name
                    .uppercased()
            )
            .font(
                .system(
                    size: 25,
                    weight: .semibold
                )
            )
            .tracking(3)
            .foregroundStyle(
                .cyan
            )

            Text(
                current.date.formatted(
                    date: .complete,
                    time: .shortened
                )
            )
            .foregroundStyle(
                .secondary
            )

            HStack(
                spacing: 70
            ) {
                detailTeam(
                    current.home
                )

                VStack(
                    spacing: 8
                ) {
                    if current.showsScore {
                        Text(
                            "\(current.homeScore ?? "–")  –  \(current.awayScore ?? "–")"
                        )
                        .font(
                            .system(
                                size: 52,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                    } else {
                        Text(
                            "VS"
                        )
                        .font(
                            .system(
                                size: 32,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Text(
                        current.status
                    )
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        current.phase == .live
                            ? .cyan
                            : .secondary
                    )
                }

                detailTeam(
                    current.away
                )
            }

            if let venue =
                current.venue
            {
                Label(
                    venue,
                    systemImage:
                        "mappin.and.ellipse"
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Text(
                "Tik op een team om het favoriet te maken"
            )
            .font(
                .system(
                    size: 21
                )
            )
            .foregroundStyle(
                .secondary
            )

            HStack(
                spacing: 30
            ) {
                favoriteButton(
                    current.home
                )

                favoriteButton(
                    current.away
                )
            }

            if current.phase != .finished {
                Button {
                    channelQuery = SportChannelQuery(
                        title: "\(current.home.name) – \(current.away.name)",
                        teams: [current.home.name, current.away.name],
                        start: current.date
                    )
                } label: {
                    Label(
                        "Waar kijken?",
                        systemImage:
                            "play.tv"
                    )
                }
            }

            NavigationLink {
                LiveTVView()
            } label: {
                Label(
                    "Open mijn Live TV",
                    systemImage:
                        "tv"
                )
            }

            Text(
                "Kies zelf een zender uit je eigen Live TV-aanbod."
            )
            .font(
                .system(
                    size: 21
                )
            )
            .foregroundStyle(
                .secondary
            )

            SportsFeedStatus(
                store: store
            )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .preferredColorScheme(
            .dark
        )
        .background(
            LinearGradient(
                colors: [
                    sportsNavy,
                    Color(
                        red: 0.02,
                        green: 0.10,
                        blue: 0.15
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .sportChannelSheet($channelQuery) { playing = $0 }
        .navigationDestination(item: $playing) { source in
            PlayerView(
                source: source,
                item: MediaItem(title: source.name, type: .liveTV)
            )
        }
        .task(id: scenePhase) {
            guard
                scenePhase == .active
            else {
                return
            }

            while !Task.isCancelled {
                await store.refresh(
                    date:
                        match.date
                )

                do {
                    try await Task.sleep(
                        for: .seconds(60)
                    )
                } catch {
                    return
                }
            }
        }
    }

    // MARK: - Detail Team

    private func detailTeam(
        _ team:
            SportsTeam
    ) -> some View {
        VStack(
            spacing: 16
        ) {
            SportsTeamLogo(
                team: team,
                size: 120
            )

            Text(
                team.name
            )
            .font(
                .system(
                    size: 24,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                .white
            )
            .multilineTextAlignment(
                .center
            )
            .frame(
                width: 250
            )
        }
    }

    // MARK: - Favorite Button

    private func favoriteButton(
        _ team:
            SportsTeam
    ) -> some View {
        Button {
            store.toggle(
                team
            )
        } label: {
            HStack(
                spacing: 12
            ) {
                SportsTeamLogo(
                    team: team,
                    size: 38
                )

                Label(
                    team.name,
                    systemImage:
                        store.favorites.contains(
                            team.id
                        )
                        ? "star.fill"
                        : "star"
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        SportsView()
    }
}
