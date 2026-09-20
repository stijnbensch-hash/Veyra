import Foundation

struct XtreamClient {
    private let configuration: XtreamConfiguration
    private let session: URLSession

    init(
        configuration: XtreamConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    // MARK: - Live TV

    func liveCategories() async throws -> [IPTVCategory] {
        let url = try apiURL(
            action: "get_live_categories"
        )

        let categories: [XtreamCategoryResponse] =
            try await request(url: url)

        return categories.map { category in
            IPTVCategory(
                id: category.categoryID,
                name: category.categoryName,
                contentType: .live
            )
        }
    }

    func liveChannels(
        categoryID: String? = nil
    ) async throws -> [IPTVChannel] {
        let url = try apiURL(
            action: "get_live_streams",
            categoryID: categoryID
        )

        let streams: [XtreamLiveStreamResponse] =
            try await request(url: url)

        return streams.compactMap { stream in
            guard
                let streamURL = liveStreamURL(
                    streamID: stream.streamID
                )
            else {
                return nil
            }

            return IPTVChannel(
                id: "xtream-live-\(stream.streamID)",
                name: stream.name,
                streamURL: streamURL,
                logoURL: URL(
                    string: stream.streamIcon ?? ""
                ),
                group: stream.categoryID,
                tvgID: stream.epgChannelID,
                sourceType: .xtream,
                contentType: .live
            )
        }
    }

    // MARK: - VOD movies

    func vodCategories() async throws -> [IPTVCategory] {
        let url = try apiURL(
            action: "get_vod_categories"
        )

        let categories: [XtreamCategoryResponse] =
            try await request(url: url)

        return categories.map { category in
            IPTVCategory(
                id: category.categoryID,
                name: category.categoryName,
                contentType: .vod
            )
        }
    }

    func vodStreams(
        categoryID: String? = nil
    ) async throws -> [IPTVVODItem] {
        let url = try apiURL(
            action: "get_vod_streams",
            categoryID: categoryID
        )

        let streams: [XtreamVODStreamResponse] =
            try await request(url: url)

        return streams.compactMap { stream in
            let fileExtension =
                normalizedExtension(
                    stream.containerExtension
                )

            guard
                let streamURL = vodStreamURL(
                    streamID: stream.streamID,
                    fileExtension: fileExtension
                )
            else {
                return nil
            }

            return IPTVVODItem(
                id: "xtream-vod-\(stream.streamID)",
                name: stream.name,
                streamURL: streamURL,
                posterURL: URL(
                    string: stream.streamIcon ?? ""
                ),
                categoryID: stream.categoryID,
                containerExtension: fileExtension,
                sourceType: .xtream
            )
        }
    }

    // MARK: - Series

    func series(
        categoryID: String? = nil
    ) async throws -> [XtreamSeriesItem] {
        let url = try apiURL(
            action: "get_series",
            categoryID: categoryID
        )

        let values: [XtreamSeriesResponse] =
            try await request(url: url)

        return values.compactMap { value in
            guard value.seriesID > 0 else {
                return nil
            }

            return XtreamSeriesItem(
                id: value.seriesID,
                name: value.name,
                categoryID: value.categoryID,
                coverURL: URL(
                    string: value.cover ?? ""
                )
            )
        }
    }

    func seriesInfo(
        seriesID: Int
    ) async throws -> XtreamSeriesInfo {
        let url = try apiURL(
            action: "get_series_info",
            seriesID: seriesID
        )

        let response: XtreamSeriesInfoResponse =
            try await request(url: url)

        var result: [XtreamSeriesEpisode] = []

        for (seasonKey, episodes) in response.episodes {
            let fallbackSeason =
                Int(seasonKey)

            for episode in episodes {
                guard
                    let episodeID = episode.id,
                    episodeID > 0
                else {
                    continue
                }

                let season =
                    episode.season
                    ?? fallbackSeason

                guard
                    let season,
                    season >= 0,
                    let episodeNumber =
                        episode.episodeNumber,
                    episodeNumber > 0
                else {
                    continue
                }

                let fileExtension =
                    normalizedExtension(
                        episode.containerExtension
                    )

                guard
                    let streamURL =
                        seriesStreamURL(
                            episodeID: episodeID,
                            fileExtension:
                                fileExtension
                        )
                else {
                    continue
                }

                result.append(
                    XtreamSeriesEpisode(
                        id: episodeID,
                        seasonNumber: season,
                        episodeNumber:
                            episodeNumber,
                        title:
                            cleanString(
                                episode.title
                            )
                            ?? "Aflevering \(episodeNumber)",
                        containerExtension:
                            fileExtension,
                        streamURL:
                            streamURL
                    )
                )
            }
        }

        return XtreamSeriesInfo(
            episodes: result
                .sorted {
                    if $0.seasonNumber
                        != $1.seasonNumber
                    {
                        return $0.seasonNumber
                            < $1.seasonNumber
                    }

                    return $0.episodeNumber
                        < $1.episodeNumber
                }
        )
    }

    // MARK: - API

    private func apiURL(
        action: String,
        categoryID: String? = nil,
        seriesID: Int? = nil
    ) throws -> URL {
        let playerAPIURL =
            configuration.serverURL
                .appendingPathComponent(
                    "player_api.php"
                )

        guard
            var components =
                URLComponents(
                    url: playerAPIURL,
                    resolvingAgainstBaseURL:
                        false
                )
        else {
            throw XtreamError.invalidURL
        }

        var queryItems = [
            URLQueryItem(
                name: "username",
                value:
                    configuration.username
            ),
            URLQueryItem(
                name: "password",
                value:
                    configuration.password
            ),
            URLQueryItem(
                name: "action",
                value: action
            )
        ]

        if let categoryID {
            queryItems.append(
                URLQueryItem(
                    name: "category_id",
                    value: categoryID
                )
            )
        }

        if let seriesID {
            queryItems.append(
                URLQueryItem(
                    name: "series_id",
                    value:
                        String(seriesID)
                )
            )
        }

        components.queryItems =
            queryItems

        guard
            let url = components.url
        else {
            throw XtreamError.invalidURL
        }

        return url
    }

    // MARK: - Stream URLs

    private func liveStreamURL(
        streamID: Int
    ) -> URL? {
        configuration.serverURL
            .appendingPathComponent("live")
            .appendingPathComponent(
                configuration.username
            )
            .appendingPathComponent(
                configuration.password
            )
            .appendingPathComponent(
                "\(streamID).ts"
            )
    }

    private func vodStreamURL(
        streamID: Int,
        fileExtension: String
    ) -> URL? {
        configuration.serverURL
            .appendingPathComponent("movie")
            .appendingPathComponent(
                configuration.username
            )
            .appendingPathComponent(
                configuration.password
            )
            .appendingPathComponent(
                "\(streamID).\(fileExtension)"
            )
    }

    private func seriesStreamURL(
        episodeID: Int,
        fileExtension: String
    ) -> URL? {
        configuration.serverURL
            .appendingPathComponent(
                "series"
            )
            .appendingPathComponent(
                configuration.username
            )
            .appendingPathComponent(
                configuration.password
            )
            .appendingPathComponent(
                "\(episodeID).\(fileExtension)"
            )
    }

    // MARK: - Helpers

    private func normalizedExtension(
        _ value: String?
    ) -> String {
        let value = value?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .trimmingCharacters(
                in: CharacterSet(
                    charactersIn: "."
                )
            )

        guard
            let value,
            !value.isEmpty
        else {
            return "mp4"
        }

        return value
    }

    private func cleanString(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let result =
            value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return result.isEmpty
            ? nil
            : result
    }

    // MARK: - Networking

    private func request<Response: Decodable>(
        url: URL
    ) async throws -> Response {
        var request =
            URLRequest(url: url)

        request.timeoutInterval = 30

        request.cachePolicy =
            .reloadIgnoringLocalCacheData

        let (data, response) =
            try await session.data(
                for: request
            )

        guard
            let httpResponse =
                response
                    as? HTTPURLResponse
        else {
            throw XtreamError.invalidResponse
        }

        guard
            (200...299).contains(
                httpResponse.statusCode
            )
        else {
            throw XtreamError.httpError(
                httpResponse.statusCode
            )
        }

        do {
            return try JSONDecoder()
                .decode(
                    Response.self,
                    from: data
                )
        } catch {
            throw XtreamError
                .decodingFailed(
                    error
                )
        }
    }
}

// MARK: - Public series models

nonisolated struct XtreamSeriesItem:
    Identifiable,
    Hashable,
    Codable,
    Sendable
{
    let id: Int
    let name: String
    let categoryID: String?
    let coverURL: URL?
}

struct XtreamSeriesInfo:
    Hashable
{
    let episodes:
        [XtreamSeriesEpisode]
}

nonisolated struct XtreamSeriesEpisode:
    Identifiable,
    Hashable,
    Codable,
    Sendable
{
    let id: Int

    let seasonNumber:
        Int

    let episodeNumber:
        Int

    let title:
        String

    let containerExtension:
        String

    let streamURL:
        URL
}

// MARK: - Responses

private struct XtreamCategoryResponse:
    Decodable
{
    let categoryID: String
    let categoryName: String

    enum CodingKeys:
        String,
        CodingKey
    {
        case categoryID =
            "category_id"

        case categoryName =
            "category_name"
    }
}

private struct XtreamLiveStreamResponse:
    Decodable
{
    let streamID: Int
    let name: String
    let streamIcon: String?
    let categoryID: String?
    let epgChannelID: String?

    enum CodingKeys:
        String,
        CodingKey
    {
        case streamID =
            "stream_id"

        case name

        case streamIcon =
            "stream_icon"

        case categoryID =
            "category_id"

        case epgChannelID =
            "epg_channel_id"
    }
}

private struct XtreamVODStreamResponse:
    Decodable
{
    let streamID: Int
    let name: String
    let streamIcon: String?
    let categoryID: String?
    let containerExtension: String?

    enum CodingKeys:
        String,
        CodingKey
    {
        case streamID =
            "stream_id"

        case name

        case streamIcon =
            "stream_icon"

        case categoryID =
            "category_id"

        case containerExtension =
            "container_extension"
    }
}

private struct XtreamSeriesResponse:
    Decodable
{
    let seriesID: Int
    let name: String
    let cover: String?
    let categoryID: String?

    enum CodingKeys:
        String,
        CodingKey
    {
        case seriesID =
            "series_id"

        case name
        case cover

        case categoryID =
            "category_id"
    }
}

private struct XtreamSeriesInfoResponse:
    Decodable
{
    let episodes:
        [String: [XtreamEpisodeResponse]]
}

private struct XtreamEpisodeResponse:
    Decodable
{
    let id: Int?
    let episodeNumber: Int?
    let season: Int?
    let title: String?
    let containerExtension: String?

    enum CodingKeys:
        String,
        CodingKey
    {
        case id

        case episodeNumber =
            "episode_num"

        case season
        case title

        case containerExtension =
            "container_extension"
    }

    init(
        from decoder: Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy:
                    CodingKeys.self
            )

        id =
            Self.decodeInt(
                container,
                key: .id
            )

        episodeNumber =
            Self.decodeInt(
                container,
                key: .episodeNumber
            )

        season =
            Self.decodeInt(
                container,
                key: .season
            )

        title =
            try container
                .decodeIfPresent(
                    String.self,
                    forKey: .title
                )

        containerExtension =
            try container
                .decodeIfPresent(
                    String.self,
                    forKey:
                        .containerExtension
                )
    }

    private static func decodeInt(
        _ container:
            KeyedDecodingContainer<
                CodingKeys
            >,
        key: CodingKeys
    ) -> Int? {
        if let value =
            try? container.decodeIfPresent(
                Int.self,
                forKey: key
            )
        {
            return value
        }

        if let string =
            try? container.decodeIfPresent(
                String.self,
                forKey: key
            )
        {
            return Int(string)
        }

        return nil
    }
}

// MARK: - Errors

enum XtreamError:
    LocalizedError
{
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "De Xtream-server-URL is ongeldig."

        case .invalidResponse:
            return "De Xtream-server gaf een ongeldig antwoord."

        case .httpError(
            let statusCode
        ):
            return "De Xtream-server gaf HTTP-status \(statusCode)."

        case .decodingFailed:
            return "Het antwoord van de Xtream-server kon niet worden verwerkt."
        }
    }
}
