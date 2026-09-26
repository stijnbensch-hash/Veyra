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
        try await catalogSeries(path: "/3/tv/popular")
    }

    func topRatedSeries() async throws -> [TMDBSeries] {
        try await catalogSeries(path: "/3/tv/top_rated")
    }

    func onTheAirSeries() async throws -> [TMDBSeries] {
        try await catalogSeries(path: "/3/tv/on_the_air")
    }

    func trendingSeries(window: String = "week") async throws -> [TMDBSeries] {
        try await catalogSeries(path: "/3/trending/tv/\(window)")
    }

    private func catalogSeries(path: String) async throws -> [TMDBSeries] {
        var titles: [TMDBSeries] = []
        for page in 1...5 {
            let response: TMDBSeriesPage = try await request(
                path: path, queryItems: [.init(name: "page", value: String(page))]
            )
            titles.append(contentsOf: response.results.filter { TMDBCatalogLanguageFilter.allows($0.originalLanguage) })
            if titles.count >= 20 || page >= response.totalPages { break }
        }
        return Array(titles.prefix(20))
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

    /// De trailers/teasers van TMDB zelf (meestal YouTube-video's), voor de
    /// "Trailer"-knop op het seriedetailscherm.
    func videos(forSeriesID seriesID: Int) async throws -> [TMDBVideo] {
        let response: TMDBVideosResponse = try await request(
            path: "/3/tv/\(seriesID)/videos"
        )
        return response.results
    }

    /// Series "van hetzelfde type/genre" als de opgegeven serie, voor de
    /// "Vergelijkbaar"-rij onderaan het seriedetailscherm.
    func similarSeries(id: Int) async throws -> [TMDBSeries] {
        let response: TMDBSeriesPage = try await request(path: "/3/tv/\(id)/similar")
        return response.results.filter { TMDBCatalogLanguageFilter.allows($0.originalLanguage) }
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
                value: CatalogLocalization.language
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
