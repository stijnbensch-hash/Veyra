import SwiftUI

private let sportsNavy =
    Color(
        red: 0.015,
        green: 0.045,
        blue: 0.075
    )

// MARK: - Sports Center

struct SportsView: View {
    @StateObject
    private var store =
        SportsStore()

    @Environment(\.scenePhase)
    private var scenePhase

    @State
    private var date =
        Calendar.current.startOfDay(
            for: Date()
        )

    @State
    private var leagueID: String?

    @State
    private var filter =
        SportsFilter.all

    @State
    private var favoritesOnly =
        false

    @State
    private var selectedMatch:
        SportsMatch?

    @FocusState
    private var focusedMatchID:
        String?

    private var filtered:
        [SportsMatch]
    {
        store.matches.filter {
            (
                leagueID == nil
                || $0.league.id == leagueID
            )
            &&
            (
                !favoritesOnly
                || store.isFavorite($0)
            )
            &&
            filter.accepts($0)
        }
    }

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 40
        ) {
            sidebar

            content
        }
        .padding(
            .horizontal,
            64
        )
        .padding(
            .vertical,
            35
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
        .preferredColorScheme(
            .dark
        )
        .navigationTitle(
            "Sport"
        )
        .navigationDestination(
            item: $selectedMatch
        ) { match in
            SportsMatchView(
                match: match,
                store: store
            )
        }
        .task(id: date) {
            await store.refresh(
                date: date
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
                    date: date
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
        .toolbar {
            Button {
                Task {
                    await store.refresh(
                        date: date,
                        force: true
                    )
                }
            } label: {
                Label(
                    "Vernieuwen",
                    systemImage:
                        "arrow.clockwise"
                )
            }
            .disabled(
                store.isLoading
            )
        }
    }

    // MARK: - Sidebar

    private var sidebar:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            Text(
                "SPORTCENTRUM"
            )
            .font(
                .system(
                    size: 22,
                    weight: .bold
                )
            )
            .tracking(3)
            .foregroundStyle(
                .cyan
            )

            Text(
                "Jouw sport.\nIn beeld."
            )
            .font(
                .system(
                    size: 44,
                    weight: .bold
                )
            )
            .padding(
                .bottom,
                24
            )

            Button {
                leagueID = nil
            } label: {
                Label(
                    "Alle competities",
                    systemImage:
                        leagueID == nil
                        ? "checkmark.circle.fill"
                        : "globe.europe.africa"
                )
            }

            ForEach(
                SportsLeague.all
            ) { league in
                Button {
                    leagueID =
                        league.id
                } label: {
                    Label(
                        league.name,
                        systemImage:
                            leagueID == league.id
                            ? "checkmark.circle.fill"
                            : league.symbol
                    )
                }
            }

            Toggle(
                "Mijn teams",
                isOn:
                    $favoritesOnly
            )
            .padding(
                .top,
                24
            )

            Text(
                "Open een wedstrijd en geef je favoriete teams een ster."
            )
            .font(
                .system(
                    size: 20
                )
            )
            .foregroundStyle(
                .secondary
            )

            Spacer()
        }
        .font(
            .system(
                size: 23,
                weight: .medium
            )
        )
        .buttonStyle(
            .bordered
        )
        .frame(
            width: 330,
            alignment: .leading
        )
    }

    // MARK: - Main Content

    private var content:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 28
        ) {
            dateHeader

            Picker(
                "Wedstrijden",
                selection:
                    $filter
            ) {
                ForEach(
                    SportsFilter.allCases
                ) {
                    Text(
                        $0.rawValue
                    )
                    .tag($0)
                }
            }
            .pickerStyle(
                .segmented
            )

            SportsFeedStatus(
                store: store
            )

            if filtered.isEmpty {
                ContentUnavailableView(
                    store.isLoading
                        ? "Scores laden"
                        : "Geen wedstrijden",
                    systemImage:
                        store.isLoading
                        ? "clock"
                        : "sportscourt",
                    description:
                        Text(
                            emptyMessage
                        )
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(
                                .flexible()
                            ),
                            GridItem(
                                .flexible()
                            )
                        ],
                        spacing: 28
                    ) {
                        ForEach(
                            filtered
                        ) { match in
                            matchControl(
                                match
                            )
                        }
                    }
                    .padding(16)
                }
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - Date Header

    private var dateHeader:
        some View
    {
        HStack(
            spacing: 24
        ) {
            Button {
                changeDate(-1)
            } label: {
                Image(
                    systemName:
                        "chevron.left"
                )
            }
            .accessibilityLabel(
                "Vorige dag"
            )

            Text(
                date.formatted(
                    .dateTime
                        .weekday(.wide)
                        .day()
                        .month(.wide)
                )
            )
            .font(
                .system(
                    size: 30,
                    weight: .semibold
                )
            )
            .frame(
                maxWidth:
                    .infinity
            )

            Button {
                changeDate(1)
            } label: {
                Image(
                    systemName:
                        "chevron.right"
                )
            }
            .accessibilityLabel(
                "Volgende dag"
            )

            Button(
                "Vandaag"
            ) {
                date =
                    Calendar.current
                        .startOfDay(
                            for: Date()
                        )
            }
        }
    }

    // MARK: - Match Control

    private func matchControl(
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

    // MARK: - Empty Message

    private var emptyMessage:
        String
    {
        if store.isLoading {
            return
                "Het programma en de uitslagen worden opgehaald."
        }

        if !store
            .failedLeagues
            .isEmpty
        {
            return
                "Een deel van de scores is niet bereikbaar. Probeer Vernieuwen."
        }

        return favoritesOnly
            ? "Geen wedstrijden voor je favoriete teams bij deze selectie. Zet Mijn teams uit om andere teams te vinden."
            : "Kies een andere dag, competitie of filter."
    }

    private func changeDate(
        _ delta: Int
    ) {
        date =
            Calendar.current.date(
                byAdding: .day,
                value: delta,
                to: date
            )
            ?? date
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
            HStack {
                Label(
                    "SPORT VANDAAG",
                    systemImage:
                        "sportscourt.fill"
                )
                .font(
                    .system(
                        size: 25,
                        weight: .bold
                    )
                )
                .tracking(2)
                .foregroundStyle(
                    .cyan
                )

                Spacer()
            }

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
                        ? .cyan
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
                cornerRadius: 20,
                style: .continuous
            )
            .fill(
                isFocused
                    ? Color.cyan.opacity(
                        0.16
                    )
                    : Color(
                        red: 0.035,
                        green: 0.10,
                        blue: 0.15
                    )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                    ? Color.cyan
                    : Color.cyan.opacity(
                        match.phase == .live
                            ? 0.65
                            : 0.15
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
                AsyncImage(
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
