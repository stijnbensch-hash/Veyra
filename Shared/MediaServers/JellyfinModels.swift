import Foundation

// MARK: - Library (Jellyfin "View")

struct JellyfinLibrary:
    Identifiable,
    Decodable,
    Hashable
{
    let id: String
    let name: String
    let collectionType: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case collectionType = "CollectionType"
    }

    var symbol: String {
        switch collectionType {
        case "movies":
            return "film"

        case "tvshows":
            return "tv"

        case "music":
            return "music.note"

        default:
            return "square.stack.3d.up"
        }
    }
}

// MARK: - Item (movie, series or episode)

struct JellyfinItem:
    Identifiable,
    Decodable,
    Hashable
{
    let id: String
    let name: String
    let type: String
    let overview: String?
    let productionYear: Int?
    let seriesName: String?
    let seriesID: String?
    let parentIndexNumber: Int?
    let indexNumber: Int?
    let imageTags: [String: String]?
    let backdropImageTags: [String]?

    /// Voor de Better Posters-badge op `VeyraPosterCard` — alleen gevuld als
    /// de aanroep dit expliciet opvraagt via `Fields=Genres,CommunityRating`.
    let genres: [String]?
    let communityRating: Double?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case overview = "Overview"
        case productionYear = "ProductionYear"
        case seriesName = "SeriesName"
        case seriesID = "SeriesId"
        case parentIndexNumber = "ParentIndexNumber"
        case indexNumber = "IndexNumber"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
        case genres = "Genres"
        case communityRating = "CommunityRating"
    }

    /// Eerste genre, voor dezelfde badge als TMDB-gebaseerde posters.
    var primaryGenre: String? {
        genres?.first
    }

    var isMovie: Bool {
        type == "Movie"
    }

    var isSeries: Bool {
        type == "Series"
    }

    var isEpisode: Bool {
        type == "Episode"
    }

    /// Titel zoals die getoond wordt in rijen en rasters.
    var displayTitle: String {
        guard isEpisode else {
            return name
        }

        guard
            let season = parentIndexNumber,
            let episode = indexNumber
        else {
            return seriesName.map {
                "\($0) — \(name)"
            } ?? name
        }

        let code =
            String(
                format: "S%02dE%02d",
                season,
                episode
            )

        if let seriesName {
            return "\(seriesName) · \(code)"
        }

        return "\(code) — \(name)"
    }
}

// MARK: - Playback

struct JellyfinPlaybackInfo:
    Decodable
{
    let mediaSources: [JellyfinMediaSource]

    enum CodingKeys: String, CodingKey {
        case mediaSources = "MediaSources"
    }
}

struct JellyfinMediaSource:
    Identifiable,
    Decodable,
    Hashable
{
    let id: String
    let name: String?
    let path: String?
    let protocolName: String?
    let size: Int64?
    let bitrate: Int?
    let container: String?
    let isRemote: Bool?
    let supportsDirectPlay: Bool?
    let supportsDirectStream: Bool?
    let supportsTranscoding: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case path = "Path"
        case protocolName = "Protocol"
        case size = "Size"
        case bitrate = "Bitrate"
        case container = "Container"
        case isRemote = "IsRemote"
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case supportsTranscoding = "SupportsTranscoding"
    }
}
