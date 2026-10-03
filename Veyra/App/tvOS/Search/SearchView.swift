import SwiftUI

struct SearchView: View {
    // Zie MediaNavigation.swift: centrale actie i.p.v. eigen `.navigationDestination(item:)`
    // voor `MediaItem`, anders botst dit met de Home-planken in dezelfde (enige, tvOS-brede)
    // NavigationStack.
    @Environment(\.openMediaDetail) private var openMediaDetail

    @State private var movies: [TMDBMovie] = []
    @State private var series: [TMDBSeries] = []

    @State private var selectedSeries: TMDBSeries?

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var isOpeningMovie = false
    @State private var errorMessage: String?

    // Fase 7 (Search §43: pagination) -- eerste pagina snel, volgende pas bij scroll.
    @State private var moviePage = 1
    @State private var movieTotalPages = 1
    @State private var isLoadingMoreMovies = false
    @State private var seriesPage = 1
    @State private var seriesTotalPages = 1
    @State private var isLoadingMoreSeries = false

    private let posterBaseURL = URL(
        string: "https://image.tmdb.org/t/p/w500"
    )!

    var body: some View {
        VeyraDynamicBackgroundScope {
            ZStack {
                VeyraBackground()

                VStack(
                    alignment: .leading,
                    spacing: 30
                ) {
                    header
                    content
                }
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 50)

                if isOpeningMovie {
                    ZStack {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()

                        ProgressView("Film openen…")
                            .font(.system(size: 22))
                    }
                }
            }
            .searchable(
                text: $searchText,
                prompt: "Zoek films en series"
            )
            .task(id: searchText) {
                await updateSearch()
            }
            .navigationDestination(
                item: $selectedSeries
            ) { series in
                SeriesDetailView(
                    series: series
                )
            }

        }
    }

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("Zoeken")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("FILMS & SERIES")
                .font(.system(size: 18))
                .tracking(3)
                .foregroundStyle(VeyraColors.ice.opacity(0.75))
        }
    }

    @ViewBuilder
    private var content: some View {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if query.isEmpty {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                Image(systemName: "magnifyingglass")
                    .font(
                        .system(
                            size: 56,
                            weight: .light
                        )
                    )
                    .foregroundStyle(
                        .cyan.opacity(0.75)
                    )

                Text("Zoek in Veyra")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)

                Text(
                    "Zoek tegelijk naar films en series."
                )
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            }

            Spacer()
        } else if isSearching {
            ProgressView("Zoeken…")
                .font(.system(size: 22))

            Spacer()
        } else if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Text("Zoeken is mislukt")
                    .font(.system(size: 32, weight: .semibold))

                Text(errorMessage)
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        } else if movies.isEmpty && series.isEmpty {
            Text("Geen resultaten gevonden")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)

            Spacer()
        } else {
            VeyraScrollView(.vertical) {
                VStack(
                    alignment: .leading,
                    spacing: 44
                ) {
                    if !movies.isEmpty {
                        movieSection
                    }

                    if !series.isEmpty {
                        seriesSection
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }

    private var movieSection: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            sectionTitle("FILMS")

            ScrollView(.horizontal) {
                LazyHStack(
                    alignment: .top,
                    spacing: 35
                ) {
                    ForEach(movies) { movie in
                        movieCard(movie)
                            .task {
                                if movie.id == movies.last?.id { await loadMoreMoviesIfNeeded() }
                            }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 10)
            }
            .frame(height: 520)
        }
    }

    private var seriesSection: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            sectionTitle("SERIES")

            ScrollView(.horizontal) {
                LazyHStack(
                    alignment: .top,
                    spacing: 35
                ) {
                    ForEach(series) { item in
                        seriesCard(item)
                            .task {
                                if item.id == series.last?.id { await loadMoreSeriesIfNeeded() }
                            }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 10)
            }
            .frame(height: 520)
        }
    }

    private func sectionTitle(
        _ title: String
    ) -> some View {
        Text(title)
            .font(
                .system(
                    size: 29,
                    weight: .semibold
                )
            )
            .tracking(3)
            .foregroundStyle(
                .cyan.opacity(0.85)
            )
    }

    private func movieCard(
        _ movie: TMDBMovie
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            Button {
                Task {
                    await openMovie(movie)
                }
            } label: {
                poster(
                    url: posterURL(
                        path: movie.posterPath
                    ),
                    placeholderSystemName: "film"
                ).traktWatchedCheckmark(.movie(TraktIDs(tmdb: movie.id)))
            }
            .buttonStyle(.card)
            .disabled(isOpeningMovie)

            Text(movie.title)
                .font(
                    .system(
                        size: 32,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(0.85)
                )
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(
                    width: 260,
                    alignment: .leading
                )
                .frame(
                    minHeight: 64,
                    alignment: .topLeading
                )
        }
        .frame(
            width: 260,
            height: 480,
            alignment: .topLeading
        )
    }

    private func seriesCard(
        _ item: TMDBSeries
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            Button {
                selectedSeries = item
            } label: {
                poster(
                    url: posterURL(
                        path: item.posterPath
                    ),
                    placeholderSystemName: "tv"
                ).traktWatchedCheckmark(.show(TraktIDs(tmdb: item.id)))
            }
            .buttonStyle(.card)

            Text(item.name)
                .font(
                    .system(
                        size: 32,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(0.85)
                )
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(
                    width: 260,
                    alignment: .leading
                )
                .frame(
                    minHeight: 64,
                    alignment: .topLeading
                )
        }
        .frame(
            width: 260,
            height: 480,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private func poster(
        url: URL?,
        placeholderSystemName: String
    ) -> some View {
        VeyraAsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ZStack {
                    posterPlaceholder(
                        systemName: placeholderSystemName
                    )

                    ProgressView()
                }

            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()

            case .failure:
                posterPlaceholder(
                    systemName: placeholderSystemName
                )

            @unknown default:
                posterPlaceholder(
                    systemName: placeholderSystemName
                )
            }
        }
        .frame(
            width: 260,
            height: 390
        )
        .clipped()
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private func posterPlaceholder(
        systemName: String
    ) -> some View {
        ZStack {
            Color.white.opacity(0.08)

            Image(systemName: systemName)
                .font(.system(size: 55))
                .foregroundStyle(.secondary)
        }
    }

    private func posterURL(
        path: String?
    ) -> URL? {
        guard let path else {
            return nil
        }

        return posterBaseURL
            .appendingPathComponent(
                path.trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "/"
                    )
                )
            )
    }

    @MainActor
    private func updateSearch() async {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !query.isEmpty else {
            movies = []
            series = []
            errorMessage = nil
            isSearching = false
            return
        }

        do {
            try await Task.sleep(
                for: .milliseconds(350)
            )
        } catch {
            return
        }

        guard !Task.isCancelled else {
            return
        }

        await search(query: query)
    }

    @MainActor
    private func search(
        query: String
    ) async {
        isSearching = true
        errorMessage = nil

        guard
            let movieService = TMDBService(),
            let seriesService = SeriesService()
        else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."
            isSearching = false
            return
        }

        do {
            async let moviePageResult =
                movieService.searchMovies(
                    query: query,
                    page: 1
                )

            async let seriesPageResult =
                seriesService.searchSeries(
                    query: query,
                    page: 1
                )

            let results = try await (
                moviePageResult,
                seriesPageResult
            )

            guard !Task.isCancelled else {
                return
            }

            movies = results.0.results
            moviePage = results.0.page
            movieTotalPages = max(results.0.totalPages, 1)
            series = results.1.results
            seriesPage = results.1.page
            seriesTotalPages = max(results.1.totalPages, 1)
        } catch {
            guard !Task.isCancelled else {
                return
            }

            movies = []
            series = []
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }

    /// Fase 7 (Search §43): volgende pagina pas bij scroll naar het laatste item, nooit vooraf.
    @MainActor
    private func loadMoreMoviesIfNeeded() async {
        guard !isLoadingMoreMovies, moviePage < movieTotalPages else { return }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let service = TMDBService() else { return }
        isLoadingMoreMovies = true
        defer { isLoadingMoreMovies = false }
        do {
            let nextPage = moviePage + 1
            let page = try await service.searchMovies(query: query, page: nextPage)
            guard query == searchText.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            movies.append(contentsOf: page.results)
            moviePage = page.page
            movieTotalPages = max(page.totalPages, 1)
        } catch {
            // Stil negeren: de eerste pagina resultaten blijven gewoon zichtbaar.
        }
    }

    @MainActor
    private func loadMoreSeriesIfNeeded() async {
        guard !isLoadingMoreSeries, seriesPage < seriesTotalPages else { return }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let service = SeriesService() else { return }
        isLoadingMoreSeries = true
        defer { isLoadingMoreSeries = false }
        do {
            let nextPage = seriesPage + 1
            let page = try await service.searchSeries(query: query, page: nextPage)
            guard query == searchText.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            series.append(contentsOf: page.results)
            seriesPage = page.page
            seriesTotalPages = max(page.totalPages, 1)
        } catch {
            // Stil negeren: eerdere resultaten blijven gewoon zichtbaar.
        }
    }

    @MainActor
    private func openMovie(
        _ movie: TMDBMovie
    ) async {
        guard !isOpeningMovie else {
            return
        }

        isOpeningMovie = true
        errorMessage = nil

        defer {
            isOpeningMovie = false
        }

        guard let service = TMDBService() else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."
            return
        }

        do {
            let item = try await service.mediaItem(
                for: movie
            )
            openMediaDetail(item)
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
