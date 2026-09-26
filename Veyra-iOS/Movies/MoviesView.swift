import SwiftUI

struct MoviesView: View {
    @ObservedObject private var trakt = TraktStore.shared

    @State private var movies: [TMDBMovie] = []
    @State private var selectedMovieItem: MediaItem?
    @State private var isLoading = true
    @State private var isOpeningMovie = false
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

    private var metrics: VeyraPosterMetrics { VeyraPosterMetrics(regular: sizeClass == .regular) }
    private var columns: [GridItem] { metrics.columns }

    private let posterBaseURL =
        URL(string: "https://image.tmdb.org/t/p/w500")!

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraArtworkBackground(
                    url: featured?.backdropPath.flatMap {
                        URL(
                            string:
                                "https://image.tmdb.org/t/p/w1280"
                                + $0
                        )
                    }
                )
                .id(featured?.id ?? -1)
                .animation(.easeInOut(duration: 0.35), value: featured?.id)

                ScrollView(
                    .vertical,
                    showsIndicators: false
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 24
                    ) {
                        if let featured {
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
                                    ?? []
                            ) {
                                Button {
                                    Task {
                                        await openMovie(
                                            featured
                                        )
                                    }
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

                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {
                            header

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

                        content
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }

                if isOpeningMovie {
                    ProgressView(
                        "Film openen…"
                    )
                    .padding()
                    .background(
                        .ultraThinMaterial,
                        in:
                            RoundedRectangle(
                                cornerRadius: 12
                            )
                    )
                }
            }
            .toolbar(
                .hidden,
                for: .navigationBar
            )
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
            .navigationDestination(
                item: $selectedMovieItem
            ) { movie in
                MovieDetailView(
                    movie: movie
                )
            }
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
    private var content: some View {
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
                columns: columns,
                spacing: metrics.rowSpacing
            ) {
                ForEach(movies) {
                    movie in

                    Button {
                        Task {
                            await openMovie(
                                movie
                            )
                        }
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
                    .disabled(
                        isOpeningMovie
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

    @MainActor
    private func openMovie(
        _ movie: TMDBMovie
    ) async {
        guard
            !isOpeningMovie
        else {
            return
        }

        isOpeningMovie = true
        errorMessage = nil

        defer {
            isOpeningMovie = false
        }

        guard let service =
            TMDBService()
        else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."

            return
        }

        do {
            selectedMovieItem =
                try await service
                .mediaItem(
                    for: movie
                )

        } catch {
            errorMessage =
                error
                .localizedDescription
        }
    }
}

#Preview {
    MoviesView()
}
