import Foundation

struct TraktIDs: Codable, Hashable {
    var trakt: Int?
    var slug: String?
    var imdb: String?
    var tmdb: Int?

    func matches(_ other: TraktIDs) -> Bool {
        (trakt != nil && trakt == other.trakt) ||
        (tmdb != nil && tmdb == other.tmdb) ||
        (imdb != nil && imdb == other.imdb)
    }
}

struct TraktMedia: Codable, Hashable {
    var title: String?
    var year: Int?
    var ids: TraktIDs
    var season: Int?
    var number: Int?
    var overview: String?
}

struct TraktEntry: Codable, Identifiable, Hashable {
    var id: Int?
    var rank: Int?
    var type: String?
    var movie: TraktMedia?
    var show: TraktMedia?
    var episode: TraktMedia?
    var season: TraktMedia?
    var progress: Double?
    var rating: Int?
    var watchedAt: String?
    var pausedAt: String?
    var plays: Int?
    var seasons: [TraktWatchedSeason]?

    var media: TraktMedia? { movie ?? episode ?? season ?? show }
    var kind: String { movie != nil ? "movie" : episode != nil ? "episode" : season != nil ? "season" : "show" }
    var title: String {
        if let episode {
            return "\(show?.title ?? "Serie") · S\(episode.season ?? 0) E\(episode.number ?? 0) · \(episode.title ?? "Aflevering")"
        }
        if let season { return "\(show?.title ?? "Serie") · Seizoen \(season.number ?? 0)" }
        return media?.title ?? "Onbekende titel"
    }
    // History can contain several watches of the same media; watchlists may have no id.
    var rowID: String { "\(kind):\(id ?? rank ?? media?.ids.trakt ?? media?.ids.tmdb ?? 0):\(watchedAt ?? "")" }
    func matches(_ item: MediaItem) -> Bool {
        kind == item.traktKind && (media?.ids.matches(item.traktIDs) ?? false)
    }
}

struct TraktWatchedSeason: Codable, Hashable {
    var number: Int
    var episodes: [TraktWatchedEpisode]
}
struct TraktWatchedEpisode: Codable, Hashable {
    var number: Int
    var plays: Int?
}
struct TraktList: Codable, Identifiable, Hashable {
    var name: String
    var description: String?
    var privacy: String?
    var ids: TraktIDs
    var itemCount: Int?
    var id: Int { ids.trakt ?? 0 }
}
struct TraktSettings: Decodable {
    var user: TraktUser
}
struct TraktUser: Codable {
    var username: String
    var name: String?
    var ids: TraktIDs
}
struct TraktToken: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresIn: Double
    var createdAt: Double
    var expiresSoon: Bool { Date().timeIntervalSince1970 >= createdAt + expiresIn - 120 }
}
struct TraktDeviceCode: Decodable {
    var deviceCode: String
    var userCode: String
    var verificationUrl: String
    var expiresIn: Double
    var interval: Double

    /// Trakt's device-activatiepagina staat tegenwoordig op auth.trakt.tv, niet
    /// op het trakt.tv-domein dat de API in `verification_url` teruggeeft.
    /// De UI toont daarom altijd dit vaste adres, op zowel tvOS als iOS.
    var activationURL: String {
        "https://auth.trakt.tv/activate"
    }
}
struct TraktSyncResult: Decodable {
    var notFound: [String: [TraktMedia]]?
    var hasMissingItems: Bool { notFound?.values.contains { !$0.isEmpty } ?? false }
}
struct TraktScrobbleResult: Decodable {
    var action: String
}

extension MediaItem {
    var traktKind: String {
        type == .movie ? "movie" : episodeNumber != nil ? "episode" : "show"
    }
    var traktIDs: TraktIDs {
        // IMDb on a series MediaItem belongs to the SHOW, never to an episode.
        if episodeNumber != nil { return TraktIDs(tmdb: episodeTMDBID) }
        return TraktIDs(imdb: imdbID, tmdb: tmdbID)
    }
    var canSyncTrakt: Bool {
        type != .liveTV && (traktIDs.tmdb != nil || traktIDs.imdb != nil)
    }
    func traktObject(rating: Int? = nil) -> [String: Any] {
        var ids: [String: Any] = [:]
        if let tmdb = traktIDs.tmdb { ids["tmdb"] = tmdb }
        if let imdb = traktIDs.imdb { ids["imdb"] = imdb }
        var object: [String: Any] = ["ids": ids]
        if let rating { object["rating"] = rating }
        return object
    }
    func traktSyncBody(rating: Int? = nil) -> [String: Any] {
        [traktKind == "movie" ? "movies" : traktKind == "episode" ? "episodes" : "shows": [traktObject(rating: rating)]]
    }
}

struct TraktUpNext: Decodable {
    var show: TraktMedia
    var progress: TraktShowProgress
    var entry: TraktEntry? {
        guard let episode = progress.nextEpisode else { return nil }
        return TraktEntry(show: show, episode: episode)
    }
}
struct TraktShowProgress: Decodable {
    var aired: Int
    var completed: Int
    var nextEpisode: TraktMedia?
}
