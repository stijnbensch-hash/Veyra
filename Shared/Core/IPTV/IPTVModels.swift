import Foundation

enum IPTVSourceType: String, Codable, Hashable {
    case m3u
    case xtream
}

enum IPTVContentType: String, Codable, Hashable {
    case live
    case vod
    case series
}

nonisolated struct IPTVChannel: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let streamURL: URL
    let logoURL: URL?
    let group: String?
    let tvgID: String?
    let sourceType: IPTVSourceType
    let contentType: IPTVContentType

    init(
        id: String,
        name: String,
        streamURL: URL,
        logoURL: URL? = nil,
        group: String? = nil,
        tvgID: String? = nil,
        sourceType: IPTVSourceType,
        contentType: IPTVContentType = .live
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.logoURL = logoURL
        self.group = group
        self.tvgID = tvgID
        self.sourceType = sourceType
        self.contentType = contentType
    }
}

struct IPTVChannelGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let channels: [IPTVChannel]

    init(
        name: String,
        channels: [IPTVChannel]
    ) {
        self.id = name
        self.name = name
        self.channels = channels
    }
}

nonisolated struct IPTVVODItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let streamURL: URL
    let posterURL: URL?
    let categoryID: String?
    let containerExtension: String?
    let sourceType: IPTVSourceType
    // Wanneer de provider deze titel heeft toegevoegd (Xtream "added") — voor
    // het sorteren van vers toegevoegde VOD-planken op nieuwste eerst.
    let added: Date?

    init(
        id: String,
        name: String,
        streamURL: URL,
        posterURL: URL? = nil,
        categoryID: String? = nil,
        containerExtension: String? = nil,
        sourceType: IPTVSourceType,
        added: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.posterURL = posterURL
        self.categoryID = categoryID
        self.containerExtension = containerExtension
        self.sourceType = sourceType
        self.added = added
    }

    var playableSource: PlayableSource {
        PlayableSource(
            name: name,
            description: "IPTV VOD",
            url: streamURL,
            kind: .direct
        )
    }
}

nonisolated struct IPTVCategory: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let contentType: IPTVContentType
}

struct M3UConfiguration: Hashable {
    let displayName: String
    let playlistURL: URL

    init(
        displayName: String = "IPTV",
        playlistURL: URL
    ) {
        self.displayName = displayName
        self.playlistURL = playlistURL
    }
}

struct XtreamConfiguration: Hashable {
    let displayName: String
    let serverURL: URL
    let username: String
    let password: String

    init(
        displayName: String = "IPTV",
        serverURL: URL,
        username: String,
        password: String
    ) {
        self.displayName = displayName
        self.serverURL = serverURL
        self.username = username
        self.password = password
    }
}
