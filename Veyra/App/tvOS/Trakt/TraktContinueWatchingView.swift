import SwiftUI
import Foundation

@MainActor
struct TraktContinueWatchingView: View {
    @ObservedObject
    private var store = TraktStore.shared

    @FocusState
    private var focusedCardID: String?

    @State private var heroToken = UUID()

    private var watchingItems: [TraktContinueWatchingItem] {
        let pausedItems =
            store.playback.map {
                TraktContinueWatchingItem(
                    entry: $0,
                    isNextEpisode: false,
                    episodeProgress:
                        episodeProgress(
                            for: $0
                        )
                )
            }

        let nextItems =
            store.cachedUpNextEntries.map {
                TraktContinueWatchingItem(
                    entry: $0,
                    isNextEpisode: true,
                    episodeProgress:
                        episodeProgress(
                            for: $0
                        )
                )
            }

        var result: [TraktContinueWatchingItem] = []
        var seenKeys = Set<String>()

        for item in pausedItems + nextItems {
            let keys = item.identityKeys

            let alreadyIncluded =
                keys.contains {
                    seenKeys.contains($0)
                }

            seenKeys.formUnion(keys)

            if !alreadyIncluded {
                result.append(item)
            }
        }

        return result
    }

    // MARK: - Episode progress

    private func episodeProgress(
        for entry: TraktEntry
    ) -> TraktShowProgress? {
        guard
            let show =
                entry.show
        else {
            return nil
        }

        return store.upNext.first {
            value in

            value.show.ids.matches(
                show.ids
            )
        }?
        .progress
    }

    var body: some View {
        let items =
            watchingItems

        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            VeyraSectionHeader(
                title: "Verder kijken",
                subtitle: "Jouw voortgang"
            )

            if !store.isConnected {
                Text(
                    "Koppel Trakt via Instellingen om verder te kijken."
                )
                .foregroundStyle(
                    .secondary
                )

            } else if
                store.isSyncing
                && items.isEmpty
            {
                ProgressView(
                    "Trakt laden…"
                )

            } else if items.isEmpty {
                Text(
                    "Geen titels om verder te kijken."
                )
                .foregroundStyle(
                    .secondary
                )

            } else {
                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    LazyHStack(
                        alignment: .top,
                        spacing: 24
                    ) {
                        ForEach(items) {
                            item in

                            NavigationLink {
                                TraktContinueWatchingDestination(
                                    entry:
                                        item.entry
                                )

                            } label: {
                                TraktContinueWatchingCard(
                                    item:
                                        item,
                                    isFocused:
                                        focusedCardID
                                        == item.id
                                )
                            }
                            .buttonStyle(
                                VeyraContinueWatchingButtonStyle()
                            )
                            .focused(
                                $focusedCardID,
                                equals:
                                    item.id
                            )
                            .focusEffectDisabled()
                        }
                    }
                    .padding(
                        .horizontal,
                        8
                    )
                    .padding(
                        .vertical,
                        12
                    )
                }
            }

            if let message =
                store.errorMessage
            {
                Text(
                    "Trakt: \(message)"
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .orange
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }
        }
        .task(
            id:
                store.isConnected
        ) {
            guard
                store.isConnected
            else {
                return
            }

            await store
                .refreshIfNeeded()
        }
        .onChange(
            of:
                focusedCardID
        ) { _, newValue in
            updateHeroSpotlight(
                id:
                    newValue,
                items:
                    items
            )
        }
        .onDisappear {
            VeyraHeroSpotlight
                .shared
                .clear(
                    token:
                        heroToken
                )
        }
    }

    // MARK: - Hero spotlight

    private func heroTitle(
        for entry:
            TraktEntry
    ) -> String {
        if let movie =
            entry.movie
        {
            return movie.title
                ?? "Film"
        }

        if let episode =
            entry.episode
        {
            let showTitle =
                entry.show?.title
                ?? "Serie"

            if let season =
                episode.season,
               let number =
                episode.number
            {
                return
                    "\(showTitle) · S\(season) E\(number)"
            }

            return showTitle
        }

        if let show =
            entry.show
        {
            return show.title
                ?? entry.title
        }

        return entry.title
    }

    private func updateHeroSpotlight(
        id: String?,
        items:
            [TraktContinueWatchingItem]
    ) {
        guard
            let id,
            let item =
                items.first(
                    where: {
                        $0.id == id
                    }
                )
        else {
            VeyraHeroSpotlight
                .shared
                .clear(
                    token:
                        heroToken
                )

            return
        }

        let entry =
            item.entry

        let title =
            heroTitle(
                for: entry
            )

        let contentID =
            "trakt:\(item.id)"

        VeyraHeroSpotlight
            .shared
            .focus(
                VeyraHeroContent(
                    id:
                        contentID,
                    eyebrow:
                        "Verder kijken",
                    title:
                        title,
                    overview:
                        nil,
                    metadata:
                        [],
                    backdropURL:
                        nil
                ),
                token:
                    heroToken
            )

        guard
            let media =
                entry.movie
                ?? entry.show,
            let tmdbID =
                media.ids.tmdb,
            tmdbID > 0
        else {
            return
        }

        let isMovie =
            entry.movie != nil

        Task {
            guard
                let backdropURL =
                    await VeyraHeroBackdropLookup
                        .backdropURL(
                            tmdbID:
                                tmdbID,
                            isMovie:
                                isMovie
                        )
            else {
                return
            }

            guard
                focusedCardID
                    == id
            else {
                return
            }

            VeyraHeroSpotlight
                .shared
                .focus(
                    VeyraHeroContent(
                        id:
                            contentID,
                        eyebrow:
                            "Verder kijken",
                        title:
                            title,
                        overview:
                            nil,
                        metadata:
                            [],
                        backdropURL:
                            backdropURL
                    ),
                    token:
                        heroToken
                )
        }
    }
}

// MARK: - Item

private struct TraktContinueWatchingItem:
    Identifiable
{
    let entry:
        TraktEntry

    let isNextEpisode:
        Bool

    let episodeProgress:
        TraktShowProgress?

    var id: String {
        identityKeys.first
            ?? "entry:\(entry.rowID)"
    }

    var identityKeys:
        [String]
    {
        let kind =
            entry.movie != nil
            ? "movie"
            : "show"

        guard
            let media =
                entry.movie
                ?? entry.show
        else {
            return [
                "entry:\(entry.rowID)"
            ]
        }

        var keys:
            [String] = []

        if let trakt =
            media.ids.trakt,
           trakt > 0
        {
            keys.append(
                "\(kind):trakt:\(trakt)"
            )
        }

        if let tmdb =
            media.ids.tmdb,
           tmdb > 0
        {
            keys.append(
                "\(kind):tmdb:\(tmdb)"
            )
        }

        if let imdb =
            media.ids.imdb,
           !imdb.isEmpty
        {
            keys.append(
                "\(kind):imdb:\(imdb)"
            )
        }

        if let slug =
            media.ids.slug,
           !slug.isEmpty
        {
            keys.append(
                "\(kind):slug:\(slug)"
            )
        }

        if keys.isEmpty {
            let title =
                (
                    media.title
                    ?? entry.title
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

            keys.append(
                "\(kind):title:\(title):\(media.year ?? 0)"
            )
        }

        return keys
    }
}

// MARK: - Card

private struct TraktContinueWatchingCard:
    View
{
    let item:
        TraktContinueWatchingItem

    let isFocused:
        Bool

    private var entry:
        TraktEntry
    {
        item.entry
    }

    private var playbackProgress:
        Double?
    {
        guard
            !item.isNextEpisode,
            let progress =
                entry.progress,
            progress.isFinite,
            progress >= 0,
            progress < 100
        else {
            return nil
        }

        return progress
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 11
        ) {
            TraktLandscapePoster(
                entry:
                    entry
            )
            .frame(
                width: 400,
                height: 225
            )
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
            )
            .overlay {
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.06),
                        .black.opacity(0.70)
                    ],
                    startPoint:
                        .top,
                    endPoint:
                        .bottom
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                )
                .allowsHitTesting(
                    false
                )
            }
            .overlay(
                alignment:
                    .topTrailing
            ) {
                VeyraPosterBadge(
                    title:
                        item.isNextEpisode
                        ? "Volgende"
                        : "Hervatten",
                    symbol:
                        item.isNextEpisode
                        ? "forward.end.fill"
                        : "play.fill",
                    accent:
                        item.isNextEpisode
                        ? VeyraColors.cyan
                        : VeyraColors.red,
                    fontSize:
                        14
                )
                .padding(13)
            }
            .overlay(
                alignment:
                    .bottom
            ) {
                if let progress =
                    playbackProgress
                {
                    ProgressView(
                        value:
                            progress,
                        total:
                            100
                    )
                    .tint(
                        VeyraColors.cyan
                    )
                    .background(
                        .white.opacity(0.18)
                    )
                    .padding(
                        .horizontal,
                        14
                    )
                    .padding(
                        .bottom,
                        13
                    )
                }
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .stroke(
                    isFocused
                        ? LinearGradient(
                            colors: [
                                VeyraColors.ice,
                                VeyraColors.cyan,
                                VeyraColors.red
                            ],
                            startPoint:
                                .leading,
                            endPoint:
                                .trailing
                        )
                        : LinearGradient(
                            colors: [
                                .white.opacity(0.14)
                            ],
                            startPoint:
                                .leading,
                            endPoint:
                                .trailing
                        ),
                    lineWidth:
                        isFocused
                        ? 3
                        : 1
                )
                .allowsHitTesting(
                    false
                )
            }
            .shadow(
                color:
                    isFocused
                    ? VeyraColors.cyan
                        .opacity(0.30)
                    : .black.opacity(0.34),
                radius:
                    isFocused
                    ? 20
                    : 12,
                x: -5,
                y: 8
            )
            .shadow(
                color:
                    isFocused
                    ? VeyraColors.red
                        .opacity(0.20)
                    : .clear,
                radius: 18,
                x: 9,
                y: 4
            )

            // Grotere episode/serieregel.
            Text(
                displayTitle
            )
            .font(
                .system(
                    size: 28,
                    weight: .bold,
                    design: .rounded
                )
            )
            .foregroundStyle(
                .white
            )
            .lineLimit(2)
            .multilineTextAlignment(
                .leading
            )
            .frame(
                width: 400,
                alignment:
                    .leading
            )

            if let subtitle =
                episodeSubtitle
            {
                Text(
                    subtitle
                )
                .font(
                    .system(
                        size: 20,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.62)
                )
                .lineLimit(1)
                .frame(
                    width: 400,
                    alignment:
                        .leading
                )
            }

            // Alleen deze onderste regel werd groter gemaakt.
            // Hij blijft kleiner dan de episode/serietitel erboven.
            HStack(
                spacing: 10
            ) {
                Image(
                    systemName:
                        item.isNextEpisode
                        ? "forward.end.fill"
                        : "play.fill"
                )
                .font(
                    .system(
                        size: 20,
                        weight: .bold
                    )
                )

                Text(
                    playbackProgress.map {
                        "\(Int($0))% bekeken"
                    }
                    ?? (
                        item.isNextEpisode
                        ? "Volgende aflevering"
                        : "Verder kijken"
                    )
                )
                .font(
                    .system(
                        size: 22,
                        weight: .semibold,
                        design: .rounded
                    )
                )

                Spacer()

                // Alleen series krijgen x/x.
                if let progress =
                    item.episodeProgress,
                   progress.aired > 0
                {
                    Text(
                        "\(progress.completed)/\(progress.aired)"
                    )
                    .font(
                        .system(
                            size: 22,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        VeyraColors.cyan
                    )
                }
            }
            .frame(
                width: 400,
                alignment:
                    .leading
            )
            .foregroundStyle(
                VeyraColors.ice
                    .opacity(0.82)
            )
        }
        .padding(10)
        .frame(
            width: 420,
            alignment:
                .topLeading
        )
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(
                        isFocused
                        ? 0.10
                        : 0.045
                    ),
                    VeyraColors
                        .surface
                        .opacity(0.76)
                ],
                startPoint:
                    .topLeading,
                endPoint:
                    .bottomTrailing
            ),
            in:
                RoundedRectangle(
                    cornerRadius: 25,
                    style: .continuous
                )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
            .stroke(
                .white.opacity(
                    isFocused
                    ? 0.14
                    : 0.07
                ),
                lineWidth: 1
            )
        }
        .scaleEffect(
            isFocused
            ? 1.025
            : 1
        )
        .animation(
            VeyraAnimation.focus,
            value:
                isFocused
        )
        .contentShape(
            Rectangle()
        )
    }

    private var displayTitle:
        String
    {
        if let movie =
            entry.movie
        {
            return movie.title
                ?? "Film"
        }

        if let episode =
            entry.episode
        {
            let showTitle =
                entry.show?.title
                ?? "Serie"

            if let season =
                episode.season,
               let number =
                episode.number
            {
                return
                    "\(showTitle) · S\(season) E\(number)"
            }

            return showTitle
        }

        if let show =
            entry.show
        {
            return show.title
                ?? entry.title
        }

        return entry.title
    }

    private var episodeSubtitle:
        String?
    {
        guard
            let rawTitle =
                entry.episode?.title
        else {
            return nil
        }

        let title =
            rawTitle
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !title.isEmpty
        else {
            return nil
        }

        return title
    }
}

// MARK: - Destination voor Verder kijken

@MainActor
private struct TraktContinueWatchingDestination:
    View
{
    let entry:
        TraktEntry

    @State
    private var movie:
        MediaItem?

    @State
    private var series:
        TMDBSeries?

    @State
    private var errorMessage:
        String?

    @State
    private var loading =
        true

    var body: some View {
        Group {
            if let movie {
                MovieDetailView(
                    movie:
                        movie
                )

            } else if let series {
                SeriesDetailView(
                    series:
                        series
                )

            } else if let errorMessage {
                VStack(
                    spacing: 24
                ) {
                    Text(
                        "Titel kon niet worden geopend"
                    )
                    .font(
                        .system(
                            size: 30,
                            weight: .semibold
                        )
                    )

                    Text(
                        errorMessage
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .multilineTextAlignment(
                        .center
                    )

                    Button(
                        "Opnieuw proberen"
                    ) {
                        Task {
                            await resolve()
                        }
                    }
                }
                .frame(
                    maxWidth: 700
                )
                .padding(70)

            } else if loading {
                ProgressView(
                    "Titel openen…"
                )
            }
        }
        .task {
            await resolve()
        }
    }

    private func resolve()
        async
    {
        loading =
            true

        errorMessage =
            nil

        movie =
            nil

        series =
            nil

        defer {
            loading =
                false
        }

        do {
            try Task
                .checkCancellation()

            // MARK: Film

            if let film =
                entry.movie,
               let tmdbID =
                film.ids.tmdb,
               tmdbID > 0
            {
                guard
                    let service =
                        TMDBService()
                else {
                    throw TraktError
                        .configuration
                }

                let resolvedMovie =
                    try await service
                        .mediaItem(
                            forMovieID:
                                tmdbID
                        )

                try Task
                    .checkCancellation()

                movie =
                    resolvedMovie

                return
            }

            // MARK: Serie / aflevering

            guard
                let show =
                    entry.show,
                let tmdbID =
                    show.ids.tmdb,
                tmdbID > 0
            else {
                throw TraktError
                    .missingMedia
            }

            guard
                let service =
                    SeriesService()
            else {
                throw TraktError
                    .configuration
            }

            let details =
                try await service
                    .seriesDetails(
                        id:
                            tmdbID
                    )

            try Task
                .checkCancellation()

            series =
                TMDBSeries(
                    id:
                        tmdbID,
                    name:
                        details.name,
                    overview:
                        details.overview,
                    posterPath:
                        details.posterPath,
                    backdropPath:
                        details.backdropPath,
                    firstAirDate:
                        details.firstAirDate,
                    voteAverage:
                        details.voteAverage
                )

        } catch is CancellationError {
            return

        } catch {
            errorMessage =
                error
                    .localizedDescription
        }
    }
}

// MARK: - Button style

private struct VeyraContinueWatchingButtonStyle:
    ButtonStyle
{
    func makeBody(
        configuration:
            Configuration
    ) -> some View {
        configuration.label
            .opacity(
                configuration
                    .isPressed
                ? 0.85
                : 1
            )
    }
}

// MARK: - Landscape artwork

private struct TraktLandscapePoster:
    View
{
    let entry:
        TraktEntry

    @State
    private var backdropURL:
        URL?

    @State
    private var loading =
        true

    @State
    private var loadID =
        UUID()

    private var tmdbID:
        Int?
    {
        if let movie =
            entry.movie
        {
            return movie.ids.tmdb
        }

        return entry.show?
            .ids.tmdb
    }

    private var endpoint:
        String
    {
        entry.movie != nil
        ? "movie"
        : "tv"
    }

    private var artworkKey:
        String
    {
        "\(endpoint):\(tmdbID ?? 0)"
    }

    var body: some View {
        ZStack {
            Color.white
                .opacity(0.06)

            if let backdropURL {
                AsyncImage(
                    url:
                        backdropURL
                ) { phase in
                    switch phase {
                    case .success(
                        let image
                    ):
                        image
                            .resizable()
                            .scaledToFill()

                    case .empty:
                        ProgressView()

                    case .failure:
                        placeholder

                    @unknown default:
                        placeholder
                    }
                }

            } else if loading {
                ProgressView()

            } else {
                placeholder
            }
        }
        .task(
            id:
                artworkKey
        ) {
            await loadBackdrop()
        }
    }

    private var placeholder:
        some View
    {
        Image(
            systemName:
                entry.movie != nil
                ? "film"
                : "tv"
        )
        .font(
            .system(
                size: 48
            )
        )
        .foregroundStyle(
            .secondary
        )
    }

    @MainActor
    private func loadBackdrop()
        async
    {
        let currentLoadID =
            UUID()

        loadID =
            currentLoadID

        loading =
            true

        backdropURL =
            nil

        defer {
            if loadID
                == currentLoadID
            {
                loading =
                    false
            }
        }

        guard
            let tmdbID,
            tmdbID > 0,
            let token =
                AppConfiguration
                    .tmdbReadAccessToken,
            !token.isEmpty,
            let url =
                URL(
                    string:
                        "https://api.themoviedb.org/3/\(endpoint)/\(tmdbID)?language=nl-NL"
                )
        else {
            return
        }

        var request =
            URLRequest(
                url:
                    url
            )

        request.timeoutInterval =
            20

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField:
                "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )

        do {
            let (
                data,
                response
            ) =
                try await URLSession
                    .shared
                    .data(
                        for:
                            request
                    )

            guard
                !Task.isCancelled,
                loadID
                    == currentLoadID,
                let http =
                    response
                    as? HTTPURLResponse,
                (200..<300)
                    .contains(
                        http.statusCode
                    )
            else {
                return
            }

            let result =
                try JSONDecoder()
                    .decode(
                        TMDBBackdropResponse.self,
                        from:
                            data
                    )

            let paths =
                [
                    result.backdropPath,
                    result.posterPath
                ]
                .compactMap {
                    $0
                }
                .map {
                    $0.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                }

            guard
                let path =
                    paths.first(
                        where: {
                            !$0.isEmpty
                        }
                    ),
                let baseURL =
                    URL(
                        string:
                            "https://image.tmdb.org/t/p/w780"
                    )
            else {
                return
            }

            backdropURL =
                baseURL
                    .appendingPathComponent(
                        path
                            .trimmingCharacters(
                                in:
                                    CharacterSet(
                                        charactersIn:
                                            "/"
                                    )
                            )
                    )

        } catch {
            // Artwork is optioneel.
        }
    }
}

// MARK: - TMDB response

private struct TMDBBackdropResponse:
    Decodable
{
    let backdropPath:
        String?

    let posterPath:
        String?

    enum CodingKeys:
        String,
        CodingKey
    {
        case backdropPath =
            "backdrop_path"

        case posterPath =
            "poster_path"
    }
}
