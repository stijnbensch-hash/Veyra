import Foundation

struct TMDBClient {
    private let session: URLSession
    private let readAccessToken: String

    init(
        readAccessToken: String,
        session: URLSession = .shared
    ) {
        self.readAccessToken = readAccessToken
        self.session = session
    }

    func popularMovies() async throws -> [TMDBMovie] {
        let response: TMDBMoviePage = try await request(
            path: "/3/movie/popular"
        )

        return response.results
    }

    func searchMovies(query: String) async throws -> [TMDBMovie] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let response: TMDBMoviePage = try await request(
            path: "/3/search/movie",
            queryItems: [
                URLQueryItem(name: "query", value: query)
            ]
        )

        return response.results
    }

    func externalIDs(
        forMovieID movieID: Int
    ) async throws -> TMDBExternalIDs {
        try await request(
            path: "/3/movie/\(movieID)/external_ids"
        )
    }

    private func request<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        var components = URLComponents()

        components.scheme = "https"
        components.host = "api.themoviedb.org"
        components.path = path
        components.queryItems = queryItems

        guard let url = components.url else {
            throw TMDBError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        request.setValue(
            "Bearer \(readAccessToken)",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TMDBError.httpError(
                statusCode: httpResponse.statusCode
            )
        }

        do {
            return try JSONDecoder().decode(
                Response.self,
                from: data
            )
        } catch {
            throw TMDBError.decodingFailed
        }
    }
}

struct TMDBMoviePage: Decodable {
    let page: Int
    let results: [TMDBMovie]
}

struct TMDBMovie: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
    }
}

struct TMDBExternalIDs: Decodable {
    let imdbID: String?

    enum CodingKeys: String, CodingKey {
        case imdbID = "imdb_id"
    }
}

enum TMDBError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The metadata request could not be created."

        case .invalidResponse:
            return "The metadata service returned an invalid response."

        case .httpError:
            return "The metadata service could not complete the request."

        case .decodingFailed:
            return "The metadata response could not be processed."
        }
    }
}
