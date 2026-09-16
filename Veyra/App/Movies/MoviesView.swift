import SwiftUI

struct MoviesView: View {
    @State private var movies: [TMDBMovie] = []
    @State private var selectedMediaItem: MediaItem?
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

            VStack(alignment: .leading, spacing: 40) {
                Text("MOVIES")
                    .font(.system(size: 54, weight: .light))
                    .tracking(12)
                    .foregroundStyle(.white)

                if isLoading {
                    ProgressView("Loading movies…")
                        .font(.title3)

                    Spacer()
                } else if let errorMessage {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Unable to load movies")
                            .font(.title2)

                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                } else if movies.isEmpty {
                    Text("No movies available")
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
            .padding(70)

            if isOpeningMovie {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()

                    ProgressView("Opening movie…")
                        .font(.title3)
                }
            }
        }
        .task {
            await loadMovies()
        }
        .navigationDestination(
            item: $selectedMediaItem
        ) { movie in
            MovieDetailView(movie: movie)
        }
    }

    private func movieCard(_ movie: TMDBMovie) -> some View {
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
                .frame(width: 260, alignment: .leading)
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

    private func posterURL(for movie: TMDBMovie) -> URL? {
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
    private func loadMovies() async {
        isLoading = true
        errorMessage = nil

        guard let service = TMDBService() else {
            errorMessage = "The metadata service is not configured."
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
    private func openMovie(_ movie: TMDBMovie) async {
        guard !isOpeningMovie else {
            return
        }

        isOpeningMovie = true
        errorMessage = nil

        defer {
            isOpeningMovie = false
        }

        guard let service = TMDBService() else {
            errorMessage = "The metadata service is not configured."
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
