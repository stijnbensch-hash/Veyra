import SwiftUI

struct MoviesView: View {
    @State private var movies: [TMDBMovie] = []
    @State private var selectedMediaItem: MediaItem?
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var isOpeningMovie = false
    @State private var errorMessage: String?

    private let posterBaseURL = URL(
        string: "https://image.tmdb.org/t/p/w500"
    )!

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.04, blue: 0.07),
                    Color(red: 0.02, green: 0.10, blue: 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 32) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FILMS")
                            .font(.system(size: 54, weight: .light))
                            .tracking(12)
                            .foregroundStyle(.white)

                        Text(
                            searchText.isEmpty
                                ? "POPULAIR"
                                : "ZOEKRESULTATEN"
                        )
                        .font(.caption)
                        .tracking(3)
                        .foregroundStyle(.cyan.opacity(0.75))
                    }

                    Spacer()
                }

                content
            }
            .padding(70)

            if isOpeningMovie {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()

                    ProgressView("Film openen…")
                        .font(.title3)
                }
            }
        }
        .searchable(
            text: $searchText,
            prompt: "Zoek films"
        )
        .task {
            await loadPopularMovies()
        }
        .task(id: searchText) {
            await updateMovies()
        }
        .navigationDestination(
            item: $selectedMediaItem
        ) { movie in
            MovieDetailView(movie: movie)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(
                searchText.isEmpty
                    ? "Films laden…"
                    : "Zoeken…"
            )
            .font(.title3)

            Spacer()
        } else if let errorMessage {
            VStack(alignment: .leading, spacing: 16) {
                Text(
                    searchText.isEmpty
                        ? "Films konden niet worden geladen"
                        : "Zoeken is mislukt"
                )
                .font(.title2)

                Text(errorMessage)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        } else if movies.isEmpty {
            Text(
                searchText.isEmpty
                    ? "Geen films beschikbaar"
                    : "Geen films gevonden"
            )
            .foregroundStyle(.secondary)

            Spacer()
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 35) {
                    ForEach(movies) { movie in
                        Button {
                            Task {
                                await openMovie(movie)
                            }
                        } label: {
                            movieCard(movie)
                        }
                        .buttonStyle(.card)
                        .disabled(isOpeningMovie)
                    }
                }
            }
        }
    }

    private func movieCard(
        _ movie: TMDBMovie
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            AsyncImage(url: posterURL(for: movie)) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        posterPlaceholder

                        ProgressView()
                    }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    posterPlaceholder

                @unknown default:
                    posterPlaceholder
                }
            }
            .frame(width: 260, height: 390)
            .clipped()
            .clipShape(
                RoundedRectangle(cornerRadius: 18)
            )

            Text(movie.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(
                    width: 260,
                    alignment: .leading
                )
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.white.opacity(0.08)

            Image(systemName: "film")
                .font(.system(size: 55))
                .foregroundStyle(.secondary)
        }
    }

    private func posterURL(
        for movie: TMDBMovie
    ) -> URL? {
        guard let posterPath = movie.posterPath else {
            return nil
        }

        return posterBaseURL.appendingPathComponent(
            posterPath.trimmingCharacters(
                in: CharacterSet(charactersIn: "/")
            )
        )
    }

    @MainActor
    private func updateMovies() async {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if query.isEmpty {
            await loadPopularMovies()
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

        await searchMovies(query: query)
    }

    @MainActor
    private func loadPopularMovies() async {
        isLoading = true
        errorMessage = nil

        guard let service = TMDBService() else {
            errorMessage = "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }

        do {
            movies = try await service.popularMovies()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func searchMovies(
        query: String
    ) async {
        isLoading = true
        errorMessage = nil

        guard let service = TMDBService() else {
            errorMessage = "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }

        do {
            movies = try await service.searchMovies(
                query: query
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
            errorMessage = "De metadataservice is niet geconfigureerd."
            return
        }

        do {
            selectedMediaItem = try await service.mediaItem(
                for: movie
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        MoviesView()
    }
}
