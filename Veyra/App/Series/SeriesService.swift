import Foundation

struct SeriesService {
    private let readAccessToken: String

    init?() {
        guard let token = AppConfiguration.tmdbReadAccessToken else {
            return nil
        }

        self.readAccessToken = token
    }

    func popularSeries() async throws -> [TMDBSeries] {
        let response: TMDBSeriesPage = try await request(
            path: "/3/tv/popular"
        )

        return response.results
    }

    func searchSeries(
        query: String
    ) async throws -> [TMDBSeries] {
        guard !query.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return []
        }

        let response: TMDBSeriesPage = try await request(
            path: "/3/search/tv",
            queryItems: [
                URLQueryItem(
                    name: "query",
                    value: query
                )
            ]
        )

        return response.results
    }

    func seriesDetails(
        id: Int
    ) async throws -> TMDBSeriesDetails {
        try await request(
            path: "/3/tv/\(id)"
        )
    }

    func externalIDs(
        forSeriesID seriesID: Int
    ) async throws -> TMDBSeriesExternalIDs {
        try await request(
            path: "/3/tv/\(seriesID)/external_ids"
        )
    }

    func season(
        seriesID: Int,
        seasonNumber: Int
    ) async throws -> TMDBSeasonDetails {
        try await request(
            path: "/3/tv/\(seriesID)/season/\(seasonNumber)"
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

        var localizedQueryItems = queryItems
        localizedQueryItems.append(
            URLQueryItem(
                name: "language",
                value: "nl-NL"
            )
        )

        components.queryItems = localizedQueryItems

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

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

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

struct TMDBSeriesExternalIDs: Decodable, Hashable {
    let imdbID: String?

    enum CodingKeys: String, CodingKey {
        case imdbID = "imdb_id"
    }
}

struct TMDBSeriesDetails: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let numberOfSeasons: Int?
    let seasons: [TMDBSeason]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case numberOfSeasons = "number_of_seasons"
        case seasons
    }
}

struct TMDBSeasonDetails: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let overview: String?
    let seasonNumber: Int
    let posterPath: String?
    let episodes: [TMDBEpisode]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case seasonNumber = "season_number"
        case posterPath = "poster_path"
        case episodes
    }
}
