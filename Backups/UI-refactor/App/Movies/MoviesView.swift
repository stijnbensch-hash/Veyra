import SwiftUI

struct MoviesView: View {
    @State private var movies: [TMDBMovie] = []
    @State private var selectedMediaItem: MediaItem?
    @State private var isLoading = true
    @State private var isOpeningMovie = false
    @State private var errorMessage: String?
    @State private var selectedProvider: WatchProvider?
    @AppStorage("catalog.watchRegion") private var watchRegion = "BE"
    @State private var catalogRequestID = UUID()

    private let posterBaseURL = URL(
        string: "https://image.tmdb.org/t/p/w500"
    )!

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(
                        red: 0.01,
                        green: 0.04,
                        blue: 0.07
                    ),
                    Color(
                        red: 0.02,
                        green: 0.10,
                        blue: 0.16
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 20
            ) {
                header
                WatchProviderRow(kind: .movie, selection: $selectedProvider, region: $watchRegion)
                content
            }
            .padding(.horizontal, 70)
            .padding(.vertical, 36)

            if isOpeningMovie {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()

                    ProgressView("Film openen…")
                        .font(.title3)
                }
            }
        }
        .task(id: "\(watchRegion)-\(selectedProvider?.id ?? 0)") {
            await loadPopularMovies()
        }
        .onChange(of: watchRegion) { _, _ in selectedProvider = nil }
        .navigationDestination(
            item: $selectedMediaItem
        ) { movie in
            MovieDetailView(
                movie: movie
            )
        }
    }

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("FILMS")
                .font(
                    .system(
                        size: 54,
                        weight: .light
                    )
                )
                .tracking(12)
                .foregroundStyle(.white)

            Text(selectedProvider.map { "\($0.name.uppercased()) · \(watchRegion)" } ?? "POPULAIR")
                .font(.caption)
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Films laden…")
                .font(.title3)

            Spacer()
        } else if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Text(
                    "Films konden niet worden geladen"
                )
                .font(.title2)

                Text(errorMessage)
                    .foregroundStyle(.secondary)
                Button("Opnieuw proberen") { Task { await loadPopularMovies() } }
            }

            Spacer()
        } else if movies.isEmpty {
            Text("Geen films beschikbaar")
                .foregroundStyle(.secondary)

            Spacer()
        } else {
            ScrollView(.vertical) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 260, maximum: 260), spacing: 35, alignment: .top)],
                    alignment: .leading,
                    spacing: 34
                ) {
                    ForEach(movies) { movie in
                        movieCard(movie)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
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
                poster(for: movie)
            }
            .buttonStyle(.card)
            .disabled(isOpeningMovie)

            Text(movie.title)
                .font(
                    .system(
                        size: 26,
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
        for movie: TMDBMovie
    ) -> some View {
        AsyncImage(
            url: posterURL(for: movie)
        ) { phase in
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
        guard
            let posterPath = movie.posterPath
        else {
            return nil
        }

        return posterBaseURL
            .appendingPathComponent(
                posterPath.trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "/"
                    )
                )
            )
    }

    @MainActor
    private func loadPopularMovies() async {
        let requestID = UUID()
        catalogRequestID = requestID
        isLoading = true
        errorMessage = nil
        movies = []
        guard let service = TMDBService(), let token = AppConfiguration.tmdbReadAccessToken else {
            errorMessage = "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }
        do {
            let result: [TMDBMovie]
            if let selectedProvider {
                result = try await TMDBClient(readAccessToken: token).movies(providerID: selectedProvider.id, region: watchRegion)
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
        if catalogRequestID == requestID { isLoading = false }
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
            selectedMediaItem =
                try await service.mediaItem(
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
