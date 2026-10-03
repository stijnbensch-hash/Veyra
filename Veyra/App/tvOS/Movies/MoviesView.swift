import SwiftUI

struct MoviesView: View {
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

    // Automatisch roterende hero, zoals op Home: elke paar seconden een
    // andere titel uit de populairste films, zolang er geen handmatige
    // focus (heroSpotlight) actief is.
    @State private var heroRotationIndex = 0

    private let posterBaseURL = URL(
        string: "https://image.tmdb.org/t/p/w500"
    )!

    private let railSpacing: CGFloat = 32
    private let gridPosterWidth: CGFloat = 240

    @ObservedObject private var heroSpotlight = VeyraHeroSpotlight.shared

    var body: some View {
        VeyraDynamicBackgroundScope {
            ZStack {
                VeyraBackground()

                VeyraScrollView(
                    .vertical,
                    showsIndicators: false
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 28
                    ) {
                        if let featured {
                            VeyraCatalogHero(
                                url: heroSpotlight.focused?.backdropURL ?? featured.backdropPath.flatMap {
                                    URL(string: "https://image.tmdb.org/t/p/w1280" + $0)
                                },
                                topInset: VeyraTopNavigation.barHeight
                            ) {
                                Group {
                                    if let focused = heroSpotlight.focused {
                                        VeyraSpotlightHero(content: focused)
                                    } else {
                                        VeyraMovieHero(movie: featured)
                                    }
                                }
                                .id(heroSpotlight.focused?.id ?? "movie:\(featured.id)")
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            header

                            MediaFiltersRow(
                                kind: .movie,
                                selectedGenreID: $selectedGenreID,
                                selectedDecade: $selectedDecade,
                                selectedRating: $selectedRating,
                                selectedSort: $selectedSort
                            ) {
                                collectiesButton
                            }
                        }
                        .padding(.top, 24)
                        .padding(.horizontal, 80)

                        content
                            .padding(.horizontal, 80)
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(.bottom, 50)
                }
                .contentMargins(
                    .horizontal,
                    0,
                    for: .scrollContent
                )
                .scrollClipDisabled()

            }
            .ignoresSafeArea(.container, edges: [.horizontal, .top])
            .task {
                await TraktStore.shared
                    .refreshIfNeeded()
            }
            .task(
                id: catalogTaskID
            ) {
                await loadPopularMovies()
            }
            .task(id: heroPool.map(\.id)) {
                await rotateHeroAutomatically()
            }
            .onChange(
                of: watchRegion
            ) { _, _ in
                selectedProvider = nil
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
            subtitle: filterSummary,
            showChevron: false
        )
    }

    /// Zelfde formaat/stijl als de menuknoppen in `MediaFiltersRow`, maar
    /// een gewone link i.p.v. een menu -- staat vooraan die rij, i.p.v. in
    /// zijn eigen rij erboven.
    private var collectiesButton: some View {
        NavigationLink {
            VeyraCollectionsBrowserView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Bladeren")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VeyraColors.secondary)

                    Text("Collecties")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 20)
            .frame(width: 270, height: 92)
        }
        .buttonStyle(VeyraFocusButtonStyle(radius: 28))
    }

    private var filterSummary: String {
        var parts: [String] = [selectedSort.displayName]

        if let selectedProvider {
            parts.append(selectedProvider.name)
        }

        if let selectedGenreID, let name = TMDBGenreNames.movieName(for: selectedGenreID) {
            parts.append(name)
        }

        if let selectedDecade {
            parts.append(selectedDecade.title)
        }

        if let selectedRating {
            parts.append(selectedRating.title)
        }

        parts.append(watchRegion)

        return parts.joined(separator: " · ")
    }

    private var catalogTaskID: String {
        [
            watchRegion,
            catalogLanguages,
            selectedProvider?.id.description ?? "-",
            selectedGenreID?.description ?? "-",
            selectedDecade?.id ?? "-",
            selectedRating.map { String($0.rawValue) } ?? "-",
            selectedSort.rawValue,
        ]
        .joined(separator: "|")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(
                "Films laden…"
            )
            .font(.title3)

            Spacer()

        } else if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                Text(
                    "Films konden niet worden geladen"
                )
                .font(.title2)

                Text(
                    errorMessage
                )
                .foregroundStyle(
                    .secondary
                )

                Button(
                    "Opnieuw proberen"
                ) {
                    Task {
                        await loadPopularMovies()
                    }
                }
            }

            Spacer()

        } else if movies.isEmpty {
            Text(
                "Geen films beschikbaar"
            )
            .foregroundStyle(
                .secondary
            )

            Spacer()

        } else {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: gridPosterWidth, maximum: gridPosterWidth + 40), spacing: railSpacing)
                ],
                spacing: 40
            ) {
                ForEach(movies) { movie in
                    movieCard(
                        movie,
                        width: gridPosterWidth
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Movie card

    private func movieCard(
        _ movie: TMDBMovie,
        width: CGFloat
    ) -> some View {
        NavigationLink {
            MovieDetailView(movie: mediaItem(for: movie))
        } label: {
            VeyraPosterCard(
                title: movie.title,
                url: posterURL(
                    for: movie
                ),
                width: width,
                genre: TMDBGenreNames.firstMovieName(for: movie.genreIDs ?? []),
                rating: movie.voteAverage,
                year: String(movie.releaseDate?.prefix(4) ?? ""),
                tmdbID: movie.id,
                isMovie: true,
                releaseDateRaw: movie.releaseDate,
                watchedTarget: .movie(TraktIDs(tmdb: movie.id))
            )
        }
        .buttonStyle(
            VeyraPosterFocusStyle(cornerRadius: VeyraRadius.poster)
        )
        .reportsHero(.movie(movie))
        .traktMarkWatchedMenu(
            MediaItem(
                title: movie.title,
                type: .movie,
                tmdbID: movie.id
            )
        )
    }

    private func posterURL(
        for movie: TMDBMovie
    ) -> URL? {
        guard
            let posterPath =
                movie.posterPath
        else {
            return nil
        }

        return posterBaseURL
            .appendingPathComponent(
                posterPath
                    .trimmingCharacters(
                        in:
                            CharacterSet(
                                charactersIn: "/"
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
    private func loadPopularMovies()
        async
    {
        let requestID =
            UUID()

        catalogRequestID =
            requestID

        isLoading =
            true

        errorMessage =
            nil

        movies =
            []

        guard
            let service =
                TMDBService(),
            let token =
                AppConfiguration
                    .tmdbReadAccessToken
        else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."

            isLoading =
                false

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

            movies =
                result

        } catch {
            guard
                !Task.isCancelled,
                catalogRequestID
                    == requestID
            else {
                return
            }

            errorMessage =
                error.localizedDescription
        }

        if catalogRequestID
            == requestID
        {
            isLoading =
                false
        }
    }

    // MARK: - Open movie

    // Bouwt het `MediaItem` rechtstreeks uit de al beschikbare `TMDBMovie`.
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
    NavigationStack {
        MoviesView()
    }
}
