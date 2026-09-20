import SwiftUI

struct MoviesView: View {
    @State private var movies: [TMDBMovie] = []
    @State private var selectedMovieItem: MediaItem?
    @State private var isLoading = true
    @State private var isOpeningMovie = false
    @State private var errorMessage: String?
    @State private var selectedProvider: WatchProvider?

    @AppStorage("catalog.watchRegion")
    private var watchRegion = "BE"

    @State private var catalogRequestID = UUID()

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]
    private let posterBaseURL = URL(string: "https://image.tmdb.org/t/p/w500")!

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraArtworkBackground(
                    url: movies.first?.backdropPath.flatMap {
                        URL(string: "https://image.tmdb.org/t/p/w1280" + $0)
                    }
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        if let featured = movies.first {
                            VeyraHero(
                                title: featured.title,
                                eyebrow: "Uitgelicht",
                                overview: featured.overview,
                                metadata: featured.releaseDate.map { [String($0.prefix(4))] } ?? []
                            ) {
                                Button {
                                    Task { await openMovie(featured) }
                                } label: {
                                    VeyraActionLabel(title: "Meer informatie", symbol: "info.circle")
                                }
                                .buttonStyle(.plain)
                                .background(.white.opacity(0.14), in: Capsule())
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            header

                            WatchProviderRowIOS(
                                kind: .movie,
                                selection: $selectedProvider,
                                region: $watchRegion
                            )
                        }

                        content
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }

                if isOpeningMovie {
                    ProgressView("Film openen…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: watchRegion) { _, _ in selectedProvider = nil }
            .task(id: "\(watchRegion)-\(selectedProvider?.id ?? 0)") { await loadMovies() }
            .navigationDestination(item: $selectedMovieItem) { movie in
                MovieDetailView(movie: movie)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VeyraSectionHeader(
            title: "Films",
            subtitle: selectedProvider.map { "\($0.name) · \(watchRegion)" } ?? "Populair · \(watchRegion)"
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading && movies.isEmpty {
            ProgressView("Films laden…")
                .padding(.top, 20)
                .frame(maxWidth: .infinity)
        } else if let errorMessage, movies.isEmpty {
            errorView(errorMessage)
        } else if movies.isEmpty {
            ContentUnavailableView("Geen films beschikbaar", systemImage: "film")
        } else {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(movies) { movie in
                    Button {
                        Task { await openMovie(movie) }
                    } label: {
                        VeyraPosterCard(title: movie.title, url: posterURL(for: movie), width: 150)
                    }
                    .buttonStyle(.plain)
                    .disabled(isOpeningMovie)
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("Films konden niet worden geladen")
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Opnieuw proberen") {
                Task { await loadMovies() }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private func posterURL(for movie: TMDBMovie) -> URL? {
        guard let path = movie.posterPath else { return nil }
        return posterBaseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    // MARK: - Load movies

    @MainActor
    private func loadMovies() async {
        let requestID = UUID()
        catalogRequestID = requestID
        isLoading = true
        errorMessage = nil

        guard let service = TMDBService(), let token = AppConfiguration.tmdbReadAccessToken else {
            errorMessage = "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }

        do {
            let result: [TMDBMovie]

            if let selectedProvider {
                result = try await TMDBClient(readAccessToken: token)
                    .movies(providerID: selectedProvider.id, region: watchRegion)
            } else {
                result = try await service.popularMovies()
            }

            try Task.checkCancellation()
            guard catalogRequestID == requestID else { return }
            movies = result
        } catch {
            guard !Task.isCancelled, catalogRequestID == requestID else { return }
            errorMessage = error.localizedDescription
        }

        if catalogRequestID == requestID {
            isLoading = false
        }
    }

    // MARK: - Open movie

    @MainActor
    private func openMovie(_ movie: TMDBMovie) async {
        guard !isOpeningMovie else { return }
        isOpeningMovie = true
        errorMessage = nil
        defer { isOpeningMovie = false }

        guard let service = TMDBService() else {
            errorMessage = "De metadataservice is niet geconfigureerd."
            return
        }

        do {
            selectedMovieItem = try await service.mediaItem(for: movie)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    MoviesView()
}
