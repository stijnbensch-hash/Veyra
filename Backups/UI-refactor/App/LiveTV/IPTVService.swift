import Foundation

struct IPTVService {
    private let session: URLSession
    private let m3uParser: M3UParser

    init(
        session: URLSession = .shared
    ) {
        self.session = session
        self.m3uParser = M3UParser()
    }

    // MARK: - M3U

    func loadM3UChannels(
        configuration: M3UConfiguration
    ) async throws -> [IPTVChannel] {
        var request = URLRequest(
            url: configuration.playlistURL
        )

        request.timeoutInterval = 30
        request.cachePolicy =
            .reloadIgnoringLocalCacheData

        let (data, response) =
            try await session.data(
                for: request
            )

        guard
            let httpResponse =
                response as? HTTPURLResponse
        else {
            throw IPTVServiceError.invalidResponse
        }

        guard
            (200...299).contains(
                httpResponse.statusCode
            )
        else {
            throw IPTVServiceError.httpError(
                httpResponse.statusCode
            )
        }

        guard
            let content = String(
                data: data,
                encoding: .utf8
            )
        else {
            throw IPTVServiceError.invalidPlaylist
        }

        let channels =
            m3uParser.parse(content)

        guard !channels.isEmpty else {
            throw IPTVServiceError.emptyPlaylist
        }

        return channels
    }

    // MARK: - Xtream Live

    func loadXtreamLiveCategories(
        configuration: XtreamConfiguration
    ) async throws -> [IPTVCategory] {
        let client = XtreamClient(
            configuration: configuration,
            session: session
        )

        return try await client.liveCategories()
    }

    func loadXtreamLiveChannels(
        configuration: XtreamConfiguration,
        categoryID: String? = nil
    ) async throws -> [IPTVChannel] {
        let client = XtreamClient(
            configuration: configuration,
            session: session
        )

        return try await client.liveChannels(
            categoryID: categoryID
        )
    }

    // MARK: - Xtream VOD

    func loadXtreamVODCategories(
        configuration: XtreamConfiguration
    ) async throws -> [IPTVCategory] {
        let client = XtreamClient(
            configuration: configuration,
            session: session
        )

        return try await client.vodCategories()
    }

    func loadXtreamVOD(
        configuration: XtreamConfiguration,
        categoryID: String? = nil
    ) async throws -> [IPTVVODItem] {
        let client = XtreamClient(
            configuration: configuration,
            session: session
        )

        return try await client.vodStreams(
            categoryID: categoryID
        )
    }

    // MARK: - Xtream Series

    func loadXtreamSeries(
        configuration: XtreamConfiguration,
        categoryID: String? = nil
    ) async throws -> [XtreamSeriesItem] {
        let client = XtreamClient(
            configuration: configuration,
            session: session
        )

        return try await client.series(
            categoryID: categoryID
        )
    }

    func loadXtreamSeriesInfo(
        configuration: XtreamConfiguration,
        seriesID: Int
    ) async throws -> XtreamSeriesInfo {
        let client = XtreamClient(
            configuration: configuration,
            session: session
        )

        return try await client.seriesInfo(
            seriesID: seriesID
        )
    }

    // MARK: - Playback

    func playableSource(
        for channel: IPTVChannel
    ) -> PlayableSource {
        PlayableSource(
            name: channel.name,
            description: channel.group,
            url: channel.streamURL,
            kind: .liveTV
        )
    }

    func playableSource(
        for vodItem: IPTVVODItem
    ) -> PlayableSource {
        vodItem.playableSource
    }

    func playableSource(
        for episode: XtreamSeriesEpisode,
        seriesName: String
    ) -> PlayableSource {
        let code = String(
            format: "S%02dE%02d",
            episode.seasonNumber,
            episode.episodeNumber
        )

        return PlayableSource(
            name:
                "IPTV · \(seriesName) · \(code)",
            description:
                episode.title,
            url:
                episode.streamURL,
            kind:
                .iptvVOD
        )
    }
}

// MARK: - Errors

enum IPTVServiceError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case invalidPlaylist
    case emptyPlaylist

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "De IPTV-server gaf een ongeldig antwoord."

        case .httpError(let statusCode):
            return "De IPTV-server gaf HTTP-status \(statusCode)."

        case .invalidPlaylist:
            return "De M3U-afspeellijst kon niet worden gelezen."

        case .emptyPlaylist:
            return "De M3U-afspeellijst bevat geen bruikbare zenders."
        }
    }
}
