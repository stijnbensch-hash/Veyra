import SwiftUI

struct SearchView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var query = ""
    @State private var movies: [TMDBMovie] = []
    @State private var series: [TMDBSeries] = []
    @State private var selectedMovie: MediaItem?
    @State private var selectedSeries: TMDBSeries?
    @State private var isSearching = false
    @State private var isOpeningMovie = false
    @State private var errorMessage: String?

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
            .navigationDestination(item: $selectedMovie) { MovieDetailView(movie: $0) }
            .navigationDestination(item: $selectedSeries) { SeriesDetailView(series: $0) }
            .overlay {
                if isOpeningMovie {
                    ProgressView("Film openen…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
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
            async let movieResults = movieService.searchMovies(query: text)
            async let seriesResults = seriesService.searchSeries(query: text)
            let results = try await (movieResults, seriesResults)
            try Task.checkCancellation()
            movies = results.0
            series = results.1
        } catch is CancellationError {
            return
        } catch {
            movies = []
            series = []
            errorMessage = error.localizedDescription
        }
        isSearching = false
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
            selectedMovie = try await service.mediaItem(for: movie)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
