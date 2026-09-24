import Foundation

struct TMDBSeries: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let voteAverage: Double?
    /// Alleen aanwezig op lijst-/ontdek-eindpunten; zie TMDBMovie.genreIDs.
    let genreIDs: [Int]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case genreIDs = "genre_ids"
    }
}

struct TMDBSeriesPage: Decodable {
    let page: Int
    let results: [TMDBSeries]
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
    }
}

struct TMDBSeason: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let overview: String?
    let seasonNumber: Int
    let posterPath: String?
    let episodeCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case seasonNumber = "season_number"
        case posterPath = "poster_path"
        case episodeCount = "episode_count"
    }
}

struct TMDBEpisode: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let overview: String?
    let episodeNumber: Int
    let seasonNumber: Int
    let stillPath: String?
    let airDate: String?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case stillPath = "still_path"
        case airDate = "air_date"
        case voteAverage = "vote_average"
    }

    /// `airDate` (TMDB-formaat "yyyy-MM-dd") als volledige, leesbare datum,
    /// bv. "15 maart 2024" — gebruikt op de afleveringenschermen (tvOS/iOS).
    var formattedAirDate: String? {
        Self.formattedAirDate(from: airDate)
    }

    static func formattedAirDate(from raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: raw) else { return raw }
        let display = DateFormatter()
        display.locale = Locale(identifier: "nl_BE")
        display.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return display.string(from: date)
    }
}
