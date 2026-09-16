import Foundation

struct TMDBService {
    private let client: TMDBClient

    private let imageBaseURL = URL(
        string: "https://image.tmdb.org/t/p/"
    )!

    init?() {
        guard let token = AppConfiguration.tmdbReadAccessToken else {
            return nil
        }

        client = TMDBClient(
            readAccessToken: token
        )
    }

    func popularMovies() async throws -> [TMDBMovie] {
        try await client.popularMovies()
    }

    func searchMovies(query: String) async throws -> [TMDBMovie] {
        try await client.searchMovies(query: query)
    }

    func mediaItem(for movie: TMDBMovie) async throws -> MediaItem {
        let externalIDs = try await client.externalIDs(
            forMovieID: movie.id
        )

        return MediaItem(
            title: movie.title,
            type: .movie,
            imdbID: externalIDs.imdbID,
            overview: normalized(movie.overview),
            releaseDate: normalized(movie.releaseDate),
            posterURL: imageURL(
                path: movie.posterPath,
                size: "w500"
            ),
            backdropURL: imageURL(
                path: movie.backdropPath,
                size: "w1280"
            )
        )
    }

    private func imageURL(
        path: String?,
        size: String
    ) -> URL? {
        guard
            let path,
            !path.isEmpty
        else {
            return nil
        }

        return imageBaseURL
            .appendingPathComponent(size)
            .appendingPathComponent(
                path.trimmingCharacters(
                    in: CharacterSet(charactersIn: "/")
                )
            )
    }

    private func normalized(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? nil : trimmed
    }
}
