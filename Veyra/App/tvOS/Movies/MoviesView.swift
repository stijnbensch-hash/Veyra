import SwiftUI

struct MoviesView: View {
    @State private var movies: [TMDBMovie] = []
    @State private var selectedMediaItem: MediaItem?
    @State private var isLoading = true
    @State private var isOpeningMovie = false
    @State private var errorMessage: String?
    @State private var selectedProvider: WatchProvider?
    @State private var selectedGenreID: Int?
    @State private var selectedDecade: VeyraDecadeFilter?
    @State private var selectedRating: VeyraRatingFilter?

    @AppStorage("catalog.watchRegion")
    private var watchRegion = "BE"

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
        ZStack {
            VeyraArtworkBackground(
                url: heroSpotlight.focused?.backdropURL ?? featured?.backdropPath.flatMap {
                    URL(
                        string:
                            "https://image.tmdb.org/t/p/w1280"
                            + $0
                    )
                }
            )
            .id(heroSpotlight.focused?.id ?? "movie-background:\(featured?.id ?? -1)")
            .animation(.easeInOut(duration: 0.35), value: heroSpotlight.focused?.id)
            .animation(.easeInOut(duration: 0.35), value: featured?.id)

            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 28
                ) {
                    if let featured {
                        Group {
                            if let focused = heroSpotlight.focused {
                                VeyraSpotlightHero(content: focused)
                            } else {
                                VeyraMovieHero(movie: featured)
                            }
                        }
                        .id(heroSpotlight.focused?.id ?? "movie:\(featured.id)")
                        .frame(
                            minHeight: 390,
                            alignment: .center
                        )
                        .animation(.easeInOut(duration: 0.35), value: heroSpotlight.focused?.id)
                        .animation(.easeInOut(duration: 0.35), value: featured.id)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        header

                        MediaFiltersRow(
                            kind: .movie,
                            selectedGenreID: $selectedGenreID,
                            selectedDecade: $selectedDecade,
                            selectedRating: $selectedRating
                        )
                    }

                    content
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(.horizontal, 28)
                .padding(.top, 36)
                .padding(.bottom, 50)
            }
            .contentMargins(
                .horizontal,
                0,
                for: .scrollContent
            )
            .scrollClipDisabled()

            if isOpeningMovie {
                ZStack {
                    Color.black
                        .opacity(0.55)
                        .ignoresSafeArea()

                    ProgressView(
                        "Film openen…"
                    )
                    .font(.title3)
                }
            }
        }
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
        .navigationDestination(
            item: $selectedMediaItem
        ) { movie in
            MovieDetailView(
                movie: movie
            )
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
        var parts: [String] = []

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

        guard !parts.isEmpty else {
            return "Populair · \(watchRegion)"
        }

        parts.append(watchRegion)

        return parts.joined(separator: " · ")
    }

    private var catalogTaskID: String {
        [
            watchRegion,
            selectedProvider?.id.description ?? "-",
            selectedGenreID?.description ?? "-",
            selectedDecade?.id ?? "-",
            selectedRating.map { String($0.rawValue) } ?? "-",
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
        Button {
            Task {
                await openMovie(
                    movie
                )
            }

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
        .disabled(
            isOpeningMovie
        )
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
                            selectedRating?.rawValue
                    )

            } else {
                result =
                    try await service
                        .popularMovies()
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

    @MainActor
    private func openMovie(
        _ movie: TMDBMovie
    ) async {
        guard
            !isOpeningMovie
        else {
            return
        }

        isOpeningMovie =
            true

        errorMessage =
            nil

        defer {
            isOpeningMovie =
                false
        }

        guard
            let service =
                TMDBService()
        else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."

            return
        }

        do {
            selectedMediaItem =
                try await service
                    .mediaItem(
                        for: movie
                    )

        } catch {
            errorMessage =
                error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        MoviesView()
    }
}
