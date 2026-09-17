import Foundation

struct MediaItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let type: MediaType
    let imdbID: String?

    let seasonNumber: Int?
    let episodeNumber: Int?

    let overview: String?
    let releaseDate: String?
    let posterURL: URL?
    let backdropURL: URL?

    init(
        id: UUID = UUID(),
        title: String,
        type: MediaType,
        imdbID: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        overview: String? = nil,
        releaseDate: String? = nil,
        posterURL: URL? = nil,
        backdropURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.imdbID = imdbID
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.overview = overview
        self.releaseDate = releaseDate
        self.posterURL = posterURL
        self.backdropURL = backdropURL
    }
}

enum MediaType: String, Hashable {
    case movie
    case series
    case liveTV
}
