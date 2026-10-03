import SwiftUI

struct MoviesView: View {
    @ObservedObject private var trakt = TraktStore.shared
    @State private var movies: [TMDBMovie] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedProvider: WatchProvider?
    @State private var selectedGenreID: Int?
    @State private var selectedDecade: VeyraDecadeFilter?
    @State private var selectedRating: VeyraRatingFilter?
    @State private var selectedSort: VeyraSortOption = .newest

    @AppStorage("catalog.watchRegion")
    private var watchRegion = "BE"
    @AppStorage(TMDBCatalogLanguageFilter.key)
    private var catalogLanguages = "nl-en"

    @State private var catalogRequestID = UUID()

    // Automatisch roterende hero: elke paar seconden een andere titel uit
    // de populairste films.
    @State private var heroRotationIndex = 0

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let posterBaseURL =
        URL(string: "https://image.tmdb.org/t/p/w500")!

    var body: some View {
        VeyraDynamicBackgroundScope {
            NavigationStack {
                GeometryReader { geometry in
                    let metrics = VeyraCatalogPosterGridLayout(availableWidth: geometry.size.width,
                                                             regular: sizeClass == .regular)
                    ZStack {
                        VeyraBackground()

                        VeyraScrollView(
                            .vertical,
                            showsIndicators: false
                        ) {
                            VStack(
                                alignment: .leading,
                                spacing: 24
                            ) {
                                if let featured {
                                    VeyraCatalogHero(
                                        url: featured.backdropPath.flatMap {
                                            URL(string: "https://image.tmdb.org/t/p/w1280" + $0)
                                        }, topInset: VeyraSafeArea.top
                                    ) {
                                        VeyraHero(
                                            title: featured.title,
                                            eyebrow: "Uitgelicht",
                                            overview: featured.overview,
                                            metadata:
                                                featured.releaseDate.map {
                                                    [
                                                        String(
                                                            $0.prefix(4)
                                                        )
                                                    ]
                                                }
                                                ?? [],
                                            item: MediaItem(title: featured.title, type: .movie,
                                                            tmdbID: featured.id, rating: featured.voteAverage)
                                        ) {
                                            NavigationLink {
                                                MovieDetailView(movie: mediaItem(for: featured))
                                            } label: {
                                                VeyraActionLabel(
                                                    title:
                                                        "Meer informatie",
                                                    symbol:
                                                        "info.circle"
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .background(
                                                .white.opacity(0.14),
                                                in: Capsule()
                                            )
                                        }

                                    }
                                }

                                VStack(
                                    alignment: .leading,
                                    spacing: 6
                                ) {
                                    header

                                    NavigationLink {
                                        VeyraCollectionsBrowserView()
                                    } label: {
                                        Label("Collecties", systemImage: "rectangle.stack.fill")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(VeyraColors.cyan)

                                    MediaFiltersRowIOS(
                                        kind: .movie,
                                        selectedGenreID:
                                            $selectedGenreID,
                                        selectedDecade:
                                            $selectedDecade,
                                        selectedRating:
                                            $selectedRating,
                                        selectedSort:
                                            $selectedSort
                                    )
                                }

                                .padding(.horizontal, 16)

                                content(metrics: metrics)
                                    .padding(.horizontal, metrics.horizontalPadding)
                            }
                            .padding(.bottom, 40)
                        }

                    }
                }
                #if os(iOS)
                .ignoresSafeArea(.container, edges: .top)
                #endif
                .veyraHideNavigationBar()
                .onChange(
                    of: watchRegion
                ) { _, _ in
                    selectedProvider = nil
                }
                .task(
                    id: catalogTaskID
                ) {
                    async let catalogTask:
                        Void = loadMovies()

                    async let traktTask:
                        Void = refreshTrakt()

                    _ = await (
                        catalogTask,
                        traktTask
                    )
                }
                .task(id: heroPool.map(\.id)) {
                    await rotateHeroAutomatically()
                }
            }
            .mediaNavigationRoot()

        }
    }

    // MARK: - Hero rotatie

    private var heroPool: [TMDBMovie] {
        Array(movies.prefix(10))
    }

    private var featured: TMDBMovie? {
        guard !heroPool.isEmpty else { return nil }
        return heroPool[heroRotationIndex % heroPool.count]
    }

    private func rotateHeroAutomatically() async {
        heroRotationIndex = 0
        guard heroPool.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            heroRotationIndex = (heroRotationIndex + 1) % heroPool.count
        }
    }

    // MARK: - Header

    private var header: some View {
        VeyraSectionHeader(
            title: "Films",
            subtitle: filterSummary
        )
    }

    private var filterSummary: String {
        var parts: [String] = [selectedSort.displayName]

        if let selectedProvider {
            parts.append(
                selectedProvider.name
            )
        }

        if let selectedGenreID,
           let name =
            TMDBGenreNames.movieName(
                for: selectedGenreID
            )
        {
            parts.append(name)
        }

        if let selectedDecade {
            parts.append(
                selectedDecade.title
            )
        }

        if let selectedRating {
            parts.append(
                selectedRating.title
            )
        }

        parts.append(watchRegion)

        return parts.joined(
            separator: " · "
        )
    }

    private var catalogTaskID: String {
        [
            watchRegion,
            catalogLanguages,
            selectedProvider?
                .id
                .description
                ?? "-",
            selectedGenreID?
                .description
                ?? "-",
            selectedDecade?
                .id
                ?? "-",
            selectedRating.map {
                String($0.rawValue)
            }
            ?? "-",
            selectedSort.rawValue,
        ]
        .joined(
            separator: "|"
        )
    }

    // MARK: - Content

    @ViewBuilder
    private func content(metrics: VeyraCatalogPosterGridLayout) -> some View {
        if isLoading
            && movies.isEmpty
        {
            ProgressView(
                "Films laden…"
            )
            .padding(.top, 20)
            .frame(
                maxWidth: .infinity
            )

        } else if let errorMessage,
                  movies.isEmpty
        {
            errorView(
                errorMessage
            )

        } else if movies.isEmpty {
            ContentUnavailableView(
                "Geen films beschikbaar",
                systemImage: "film"
            )

        } else {
            LazyVGrid(
                columns: metrics.columns,
                spacing: metrics.rowSpacing
            ) {
                ForEach(movies) {
                    movie in

                    NavigationLink {
                        MovieDetailView(movie: mediaItem(for: movie))
                    } label: {
                        VeyraPosterCard(
                            title:
                                movie.title,
                            url:
                                posterURL(
                                    for:
                                        movie
                                ),
                            width: metrics.posterWidth,
                            genre:
                                TMDBGenreNames
                                .firstMovieName(
                                    for:
                                        movie.genreIDs
                                        ?? []
                                ),
                            rating:
                                movie.voteAverage,
                            year: String(movie.releaseDate?.prefix(4) ?? ""),
                            tmdbID: movie.id,
                            isMovie: true,
                            releaseDateRaw: movie.releaseDate,
                            watchedTarget: .movie(TraktIDs(tmdb: movie.id))
                        )
                    }
                    .buttonStyle(.plain)
                    .traktMarkWatchedMenu(
                        MediaItem(
                            title: movie.title,
                            type: .movie,
                            tmdbID: movie.id
                        )
                    )
                }
            }
        }
    }

    // MARK: - Error

    private func errorView(
        _ message: String
    ) -> some View {
        VStack(
            spacing: 12
        ) {
            Text(
                "Films konden niet worden geladen"
            )
            .font(.headline)
            .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )

            Button(
                "Opnieuw proberen"
            ) {
                Task {
                    await loadMovies()
                }
            }
        }
        .padding()
        .frame(
            maxWidth: .infinity
        )
    }

    // MARK: - Poster

    private func posterURL(
        for movie: TMDBMovie
    ) -> URL? {
        guard let path =
            movie.posterPath
        else {
            return nil
        }

        return posterBaseURL
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
    }

    private func backdropURL(
        for movie: TMDBMovie
    ) -> URL? {
        guard let path = movie.backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280" + path)
    }

    // MARK: - Load movies

    @MainActor
    private func loadMovies()
        async
    {
        let requestID = UUID()

        catalogRequestID =
            requestID

        isLoading = true
        errorMessage = nil

        guard
            let service =
                TMDBService(),
            let token =
                AppConfiguration
                .tmdbReadAccessToken
        else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."

            isLoading = false
            return
        }

        do {
            let result:
                [TMDBMovie]

            switch selectedSort {
            case .trending:
                // TMDB's trending-endpoint ondersteunt geen discover-filters
                // (provider/genre/decennium/beoordeling); bekende beperking:
                // bij "Trending" worden overige filters genegeerd.
                result =
                    try await TMDBClient(
                        readAccessToken:
                            token
                    )
                    .trendingMovies()

            case .popular:
                if selectedProvider != nil
                    || selectedGenreID != nil
                    || selectedDecade != nil
                    || selectedRating != nil
                {
                    result =
                        try await TMDBClient(
                            readAccessToken:
                                token
                        )
                        .movies(
                            providerID:
                                selectedProvider?.id,
                            region:
                                watchRegion,
                            genreID:
                                selectedGenreID,
                            minimumYear:
                                selectedDecade?.startYear,
                            maximumYear:
                                selectedDecade?.endYear,
                            minimumRating:
                                selectedRating?.rawValue,
                            sortBy:
                                "popularity.desc"
                        )

                } else {
                    result =
                        try await service
                        .popularMovies()
                }

            case .topRated:
                result =
                    try await TMDBClient(
                        readAccessToken:
                            token
                    )
                    .movies(
                        providerID:
                            selectedProvider?.id,
                        region:
                            watchRegion,
                        genreID:
                            selectedGenreID,
                        minimumYear:
                            selectedDecade?.startYear,
                        maximumYear:
                            selectedDecade?.endYear,
                        minimumRating:
                            selectedRating?.rawValue,
                        sortBy:
                            "vote_average.desc"
                    )

            case .newest:
                // Zelfde recent-uitgebracht-lijst (laatste 45 dagen, op
                // populariteit) als de "Nieuwe films"-rij op Home.
                result =
                    try await TMDBClient(
                        readAccessToken:
                            token
                    )
                    .movies(
                        providerID:
                            selectedProvider?.id,
                        region:
                            watchRegion,
                        genreID:
                            selectedGenreID,
                        minimumYear:
                            selectedDecade?.startYear,
                        maximumYear:
                            selectedDecade?.endYear,
                        minimumRating:
                            selectedRating?.rawValue,
                        sortBy:
                            "popularity.desc",
                        recentDays:
                            selectedDecade == nil ? 45 : nil
                    )
            }

            try Task
                .checkCancellation()

            guard
                catalogRequestID
                    == requestID
            else {
                return
            }

            movies = result

        } catch {
            guard
                !Task.isCancelled,
                catalogRequestID
                    == requestID
            else {
                return
            }

            errorMessage =
                error
                .localizedDescription
        }

        if catalogRequestID
            == requestID
        {
            isLoading = false
        }
    }

    // MARK: - Trakt

    @MainActor
    private func refreshTrakt()
        async
    {
        guard trakt.isConnected else {
            return
        }

        await trakt
            .refreshIfNeeded()
    }

    // MARK: - Open movie

    // Bouwt het `MediaItem` rechtstreeks uit de al beschikbare `TMDBMovie`
    // (geen netwerkcall meer voor externe id's) -- zo opent het detailscherm
    // meteen, net als bij Series. `imdbID` ontbreekt hierdoor initieel, maar
    // `MetadataRatingsService` zoekt die zelf op wanneer nodig.
    private func mediaItem(for movie: TMDBMovie) -> MediaItem {
        MediaItem(
            title: movie.title,
            type: .movie,
            tmdbID: movie.id,
            overview: normalizedOverview(movie.overview),
            releaseDate: movie.releaseDate,
            posterURL: posterURL(for: movie),
            backdropURL: backdropURL(for: movie),
            genre: TMDBGenreNames.firstMovieName(for: movie.genreIDs ?? []),
            rating: movie.voteAverage
        )
    }

    private func normalizedOverview(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    MoviesView()
}
