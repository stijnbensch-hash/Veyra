import SwiftUI

struct MoviesView: View {
    @State private var movies: [TMDBMovie] = []
    @State private var selectedMediaItem: MediaItem?
    @State private var isLoading = true
    @State private var isOpeningMovie = false
    @State private var errorMessage: String?
    @State private var selectedProvider: WatchProvider?

    @AppStorage("catalog.watchRegion")
    private var watchRegion = "BE"

    @State private var catalogRequestID = UUID()

    private let posterBaseURL = URL(
        string: "https://image.tmdb.org/t/p/w500"
    )!

    private let railSpacing: CGFloat = 24
    private let gridPosterWidth: CGFloat = 220

    @ObservedObject private var heroSpotlight = VeyraHeroSpotlight.shared

    var body: some View {
        ZStack {
            VeyraArtworkBackground(
                url: heroSpotlight.focused?.backdropURL ?? movies.first?.backdropPath.flatMap {
                    URL(
                        string:
                            "https://image.tmdb.org/t/p/w1280"
                            + $0
                    )
                }
            )
            .id(heroSpotlight.focused?.id ?? "movies-background")
            .animation(.easeInOut(duration: 0.35), value: heroSpotlight.focused?.id)

            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 28
                ) {
                    if let featured = movies.first {
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
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        header

                        WatchProviderRow(
                            kind: .movie,
                            selection: $selectedProvider,
                            region: $watchRegion
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
            id:
                "\(watchRegion)-\(selectedProvider?.id ?? 0)"
        ) {
            await loadPopularMovies()
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

    // MARK: - Header

    private var header: some View {
        VeyraSectionHeader(
            title: "Films",
            subtitle:
                selectedProvider.map {
                    "\($0.name) · \(watchRegion)"
                }
                ?? "Populair · \(watchRegion)"
        )
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
                    GridItem(.adaptive(minimum: gridPosterWidth, maximum: gridPosterWidth), spacing: railSpacing)
                ],
                spacing: 32
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
                rating: movie.voteAverage
            )
            .traktWatched(
                .movie(
                    TraktIDs(
                        tmdb: movie.id
                    )
                )
            )
        }
        .buttonStyle(
            VeyraFocusButtonStyle(
                radius:
                    VeyraRadius.poster
            )
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

            if let selectedProvider {
                result =
                    try await TMDBClient(
                        readAccessToken:
                            token
                    )
                    .movies(
                        providerID:
                            selectedProvider.id,
                        region:
                            watchRegion
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
