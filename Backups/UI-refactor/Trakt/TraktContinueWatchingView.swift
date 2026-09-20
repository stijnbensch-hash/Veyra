import SwiftUI
import Foundation

struct TraktContinueWatchingView: View {
    @ObservedObject private var store =
        TraktStore.shared

    @FocusState
    private var focusedCardID:
        String?

    // MARK: - Continue Watching

    private var watchingItems:
        [TraktContinueWatchingItem]
    {
        // 1. Echte gepauzeerde playback van Trakt.
        let pausedItems =
            store.playback
                .filter { entry in
                    guard
                        let progress =
                            entry.progress,
                        progress.isFinite,
                        progress > 0,
                        progress < 100
                    else {
                        return false
                    }

                    return true
                }
                .map {
                    TraktContinueWatchingItem(
                        entry: $0,
                        kind: .paused
                    )
                }

        // 2. Volgende aflevering, maar ALLEEN
        // wanneer die serie daadwerkelijk in
        // sync/watched/shows staat.
        let nextItems =
            store.upNext
                .compactMap(\.entry)
                .filter {
                    isWatchedShow(
                        $0
                    )
                }
                .map {
                    TraktContinueWatchingItem(
                        entry: $0,
                        kind: .nextEpisode
                    )
                }

        // Playback heeft voorrang.
        // Zo komt dezelfde serie niet twee keer terug.
        var result:
            [TraktContinueWatchingItem] = []

        var seenKeys =
            Set<String>()

        for item in
            pausedItems + nextItems
        {
            let keys =
                item.identityKeys

            let duplicate =
                keys.contains {
                    seenKeys.contains($0)
                }

            if duplicate {
                continue
            }

            seenKeys.formUnion(
                keys
            )

            result.append(
                item
            )
        }

        return result
    }

    private func isWatchedShow(
        _ entry: TraktEntry
    ) -> Bool {
        guard
            let show = entry.show
        else {
            return false
        }

        let candidateKeys =
            showIdentityKeys(
                show
            )

        guard
            !candidateKeys.isEmpty
        else {
            return false
        }

        return store
            .watchedShows
            .contains {
                watchedEntry in

                guard
                    let watchedShow =
                        watchedEntry.show
                else {
                    return false
                }

                let watchedKeys =
                    showIdentityKeys(
                        watchedShow
                    )

                return candidateKeys
                    .contains {
                        watchedKeys
                            .contains($0)
                    }
            }
    }

    private func showIdentityKeys(
        _ show: TraktMedia
    ) -> Set<String> {
        var keys =
            Set<String>()

        if let trakt =
            show.ids.trakt,
           trakt > 0
        {
            keys.insert(
                "trakt:\(trakt)"
            )
        }

        if let tmdb =
            show.ids.tmdb,
           tmdb > 0
        {
            keys.insert(
                "tmdb:\(tmdb)"
            )
        }

        if let imdb =
            show.ids.imdb?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ),
           !imdb.isEmpty
        {
            keys.insert(
                "imdb:\(imdb.lowercased())"
            )
        }

        if let slug =
            show.ids.slug?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ),
           !slug.isEmpty
        {
            keys.insert(
                "slug:\(slug.lowercased())"
            )
        }

        return keys
    }

    // MARK: - Body

    var body: some View {
        let items =
            watchingItems

        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            Text("VERDER KIJKEN")
                .font(
                    .system(
                        size: 26,
                        weight: .semibold
                    )
                )
                .tracking(4)
                .foregroundStyle(
                    .cyan
                )

            if !store.isConnected {
                Text(
                    "Koppel Trakt via Instellingen om verder te kijken."
                )
                .foregroundStyle(
                    .secondary
                )

            } else if store.isSyncing
                        && items.isEmpty {
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
                        spacing: 28
                    ) {
                        ForEach(items) {
                            item in

                            NavigationLink {
                                TraktDestinationView(
                                    entry:
                                        item.entry
                                )
                            } label: {
                                TraktContinueWatchingCard(
                                    item: item,
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
                .font(.callout)
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
            id: store.isConnected
        ) {
            guard
                store.isConnected
            else {
                return
            }

            await store
                .refreshIfNeeded()
        }
    }
}

// MARK: - Item

private struct TraktContinueWatchingItem:
    Identifiable
{
    enum Kind {
        case paused
        case nextEpisode
    }

    let entry: TraktEntry
    let kind: Kind

    var isNextEpisode:
        Bool
    {
        kind == .nextEpisode
    }

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
                "\(kind):imdb:\(imdb.lowercased())"
            )
        }

        if let slug =
            media.ids.slug,
           !slug.isEmpty
        {
            keys.append(
                "\(kind):slug:\(slug.lowercased())"
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
            progress > 0,
            progress < 100
        else {
            return nil
        }

        return progress
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            TraktLandscapePoster(
                entry: entry
            )
            .frame(
                width: 360,
                height: 203
            )
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .strokeBorder(
                    isFocused
                        ? Color.cyan
                        : Color.clear,
                    lineWidth: 3
                )
                .allowsHitTesting(
                    false
                )
            }

            Text(displayTitle)
                .font(
                    .system(
                        size: 21,
                        weight: .semibold
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
                    width: 360,
                    alignment: .leading
                )

            if let progress =
                playbackProgress
            {
                ProgressView(
                    value: progress,
                    total: 100
                )
                .tint(.cyan)
                .frame(
                    width: 360
                )

                Text(
                    "\(Int(progress))% bekeken"
                )
                .font(.caption)
                .foregroundStyle(
                    .cyan.opacity(0.8)
                )

            } else if
                item.isNextEpisode
            {
                Text(
                    "Volgende aflevering"
                )
                .font(.caption)
                .foregroundStyle(
                    .cyan.opacity(0.8)
                )
            }
        }
        .frame(
            width: 360,
            alignment: .topLeading
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
            return
                movie.title
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
            return
                show.title
                ?? "Serie"
        }

        return entry.title
    }
}

// MARK: - Button Style

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

// MARK: - Landscape Artwork

private struct TraktLandscapePoster:
    View
{
    let entry: TraktEntry

    @State private var backdropURL:
        URL?

    @State private var loading =
        true

    @State private var loadID =
        UUID()

    private var tmdbID:
        Int?
    {
        if let movie =
            entry.movie
        {
            return
                movie.ids.tmdb
        }

        return
            entry.show?
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
            Color.white.opacity(
                0.06
            )

            if let backdropURL {
                AsyncImage(
                    url: backdropURL
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
            id: artworkKey
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

        loading = true
        backdropURL = nil

        defer {
            if loadID ==
                currentLoadID
            {
                loading = false
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
                url: url
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
                        for: request
                    )

            guard
                !Task.isCancelled,
                loadID ==
                    currentLoadID,
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
                        from: data
                    )

            let paths = [
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
            // Placeholder blijft staan.
        }
    }
}

// MARK: - TMDB

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
