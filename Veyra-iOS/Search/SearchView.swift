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
    @State private var peekingMovieID: Int?
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
                                            watchedTarget: .movie(TraktIDs(tmdb: movie.id)),
                                            onPlay: { Task { await openMovieForPlay(movie) } },
                                            onOpenDetails: { Task { await openMovie(movie) } },
                                            peekTrigger: peekBinding(for: movie)
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

    private func peekBinding(for movie: TMDBMovie) -> Binding<Bool> {
        Binding(
            get: { peekingMovieID == movie.id },
            set: { peekingMovieID = $0 ? movie.id : nil }
        )
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
