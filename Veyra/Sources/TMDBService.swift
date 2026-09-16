import Foundation

struct TMDBService {
    private let client: TMDBClient

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
            imdbID: externalIDs.imdbID
        )
    }
}
