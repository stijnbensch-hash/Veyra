import Foundation

struct MediaItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let type: MediaType
    let imdbID: String?
    let tmdbID: Int?
    let episodeTMDBID: Int?

    let seasonNumber: Int?
    let episodeNumber: Int?

    let overview: String?
    let releaseDate: String?
    let posterURL: URL?
    let backdropURL: URL?

    /// Eerste/belangrijkste genre en TMDB-score, voor de Better Posters-badge
    /// op `VeyraPosterCard` (zie Shared/Theme/PosterEnrichmentSettings.swift).
    /// Alleen gevuld waar de bron dit zonder extra netwerkverzoek meegeeft
    /// (TMDB-lijsten); `nil` bij bronnen die dit niet leveren (Trakt, addons).
    let genre: String?
    let rating: Double?

    // Alleen gevuld voor `.liveTV`-items die uit een IPTV-plank komen (zie
    // `ShelfSource.iptv`) — de kant-en-klare afspeel-URL van het kanaal,
    // zodat zo'n item direct afgespeeld kan worden zonder de provider
    // opnieuw te hoeven bevragen.
    let streamURL: URL?

    init(
        id: UUID = UUID(),
        title: String,
        type: MediaType,
        imdbID: String? = nil,
        tmdbID: Int? = nil,
        episodeTMDBID: Int? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        overview: String? = nil,
        releaseDate: String? = nil,
        posterURL: URL? = nil,
        backdropURL: URL? = nil,
        genre: String? = nil,
        rating: Double? = nil,
        streamURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.imdbID = imdbID
        self.tmdbID = tmdbID
        self.episodeTMDBID = episodeTMDBID
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.overview = overview
        self.releaseDate = releaseDate
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.genre = genre
        self.rating = rating
        self.streamURL = streamURL
    }
}

enum MediaType: String, Hashable {
    case movie
    case series
    case liveTV
}
