import SwiftUI

struct SearchView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    // Navigatie via de centrale `openMediaDetail`/`playMediaItem`-omgevingsacties
    // (MediaNavigation.swift) i.p.v. een eigen `@State` + `.navigationDestination(item:)`
    // voor `MediaItem`.
    @Environment(\.openMediaDetail) private var openMediaDetail
    @Environment(\.playMediaItem) private var playMediaItem

    @State private var query = ""
    @State private var movies: [TMDBMovie] = []
    @State private var series: [TMDBSeries] = []
    @State private var selectedSeries: TMDBSeries?
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

    private var metrics: VeyraPosterMetrics {
        VeyraPosterMetrics(regular: sizeClass == .regular)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView.search
                    } else if isSearching {
                        ProgressView("Zoeken…")
                            .frame(maxWidth: .infinity)
                    } else if let errorMessage {
                        ContentUnavailableView("Zoeken is mislukt", systemImage: "exclamationmark.magnifyingglass",
                                               description: Text(errorMessage))
                    } else if movies.isEmpty && series.isEmpty {
                        ContentUnavailableView.search(text: query)
                    } else {
                        if !movies.isEmpty {
                            sectionTitle("FILMS")
                            LazyVGrid(columns: metrics.columns, spacing: metrics.rowSpacing) {
                                ForEach(movies) { movie in
                                    Button {
                                        Task { await openMovie(movie) }
                                    } label: {
                                        VeyraPosterCard(
                                            title: movie.title,
                                            url: posterURL(movie.posterPath),
                                            width: metrics.posterWidth,
                                            tmdbID: movie.id,
                                            isMovie: true,
                                            watchedTarget: .movie(TraktIDs(tmdb: movie.id))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isOpeningMovie)
                                    .task {
                                        if movie.id == movies.last?.id { await loadMoreMoviesIfNeeded() }
                                    }
                                }
                            }
                        }

                        if !series.isEmpty {
                            sectionTitle("SERIES")
                            LazyVGrid(columns: metrics.columns, spacing: metrics.rowSpacing) {
                                ForEach(series) { item in
                                    Button { selectedSeries = item } label: {
                                        VeyraPosterCard(
                                            title: item.name,
                                            url: posterURL(item.posterPath),
                                            symbol: "tv",
                                            width: metrics.posterWidth,
                                            tmdbID: item.id,
                                            isMovie: false,
                                            watchedTarget: .show(TraktIDs(tmdb: item.id))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .task {
                                        if item.id == series.last?.id { await loadMoreSeriesIfNeeded() }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
                .veyraReadableWidth()
            }
            .background(VeyraColors.background.ignoresSafeArea())
            .navigationTitle("Zoeken")
            .searchable(text: $query, prompt: "Zoek films en series")
            .task(id: query) { await search() }
            .navigationDestination(item: $selectedSeries) { SeriesDetailView(series: $0) }
            .overlay {
                if isOpeningMovie {
                    ProgressView("Film openen…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .mediaNavigationRoot()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .tracking(2)
            .foregroundStyle(VeyraColors.cyan)
    }

    private func posterURL(_ path: String?) -> URL? {
        guard let path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500" + path)
    }

    @MainActor
    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            movies = []
            series = []
            errorMessage = nil
            isSearching = false
            return
        }

        isSearching = true
        errorMessage = nil
        do {
            try await Task.sleep(for: .milliseconds(350))
            try Task.checkCancellation()
            guard let movieService = TMDBService(), let seriesService = SeriesService() else {
                errorMessage = "De metadataservice is niet ingesteld."
                isSearching = false
                return
            }
            async let moviePageResult = movieService.searchMovies(query: text, page: 1)
            async let seriesPageResult = seriesService.searchSeries(query: text, page: 1)
            let results = try await (moviePageResult, seriesPageResult)
            try Task.checkCancellation()
            movies = results.0.results
            moviePage = results.0.page
            movieTotalPages = max(results.0.totalPages, 1)
            series = results.1.results
            seriesPage = results.1.page
            seriesTotalPages = max(results.1.totalPages, 1)
        } catch is CancellationError {
            return
        } catch {
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
        guard let service = TMDBService() else { return }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isLoadingMoreMovies = true
        defer { isLoadingMoreMovies = false }
        do {
            let nextPage = moviePage + 1
            let page = try await service.searchMovies(query: text, page: nextPage)
            guard text == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
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
        guard let service = SeriesService() else { return }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isLoadingMoreSeries = true
        defer { isLoadingMoreSeries = false }
        do {
            let nextPage = seriesPage + 1
            let page = try await service.searchSeries(query: text, page: nextPage)
            guard text == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            series.append(contentsOf: page.results)
            seriesPage = page.page
            seriesTotalPages = max(page.totalPages, 1)
        } catch {
            // Stil negeren: eerdere resultaten blijven gewoon zichtbaar.
        }
    }

    @MainActor
    private func openMovie(_ movie: TMDBMovie) async {
        guard !isOpeningMovie else { return }
        isOpeningMovie = true
        defer { isOpeningMovie = false }
        guard let service = TMDBService() else {
            errorMessage = "De metadataservice is niet ingesteld."
            return
        }
        do {
            let item = try await service.mediaItem(for: movie)
            openMediaDetail(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func openMovieForPlay(_ movie: TMDBMovie) async {
        guard let service = TMDBService() else {
            errorMessage = "De metadataservice is niet ingesteld."
            return
        }
        guard let item = try? await service.mediaItem(for: movie) else { return }
        playMediaItem(item)
    }
}
