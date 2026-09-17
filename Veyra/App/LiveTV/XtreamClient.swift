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

    // MARK: - VOD

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

    // MARK: - API

    private func apiURL(
        action: String,
        categoryID: String? = nil
    ) throws -> URL {
        let playerAPIURL =
            configuration.serverURL
                .appendingPathComponent(
                    "player_api.php"
                )

        guard
            var components = URLComponents(
                url: playerAPIURL,
                resolvingAgainstBaseURL: false
            )
        else {
            throw XtreamError.invalidURL
        }

        var queryItems = [
            URLQueryItem(
                name: "username",
                value: configuration.username
            ),
            URLQueryItem(
                name: "password",
                value: configuration.password
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

        components.queryItems = queryItems

        guard let url = components.url else {
            throw XtreamError.invalidURL
        }

        return url
    }

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

    // MARK: - Networking

    private func request<Response: Decodable>(
        url: URL
    ) async throws -> Response {
        var request = URLRequest(url: url)
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
            throw XtreamError.decodingFailed(
                error
            )
        }
    }
}

// MARK: - Responses

private struct XtreamCategoryResponse: Decodable {
    let categoryID: String
    let categoryName: String

    enum CodingKeys: String, CodingKey {
        case categoryID = "category_id"
        case categoryName = "category_name"
    }
}

private struct XtreamLiveStreamResponse: Decodable {
    let streamID: Int
    let name: String
    let streamIcon: String?
    let categoryID: String?
    let epgChannelID: String?

    enum CodingKeys: String, CodingKey {
        case streamID = "stream_id"
        case name
        case streamIcon = "stream_icon"
        case categoryID = "category_id"
        case epgChannelID = "epg_channel_id"
    }
}

private struct XtreamVODStreamResponse: Decodable {
    let streamID: Int
    let name: String
    let streamIcon: String?
    let categoryID: String?
    let containerExtension: String?

    enum CodingKeys: String, CodingKey {
        case streamID = "stream_id"
        case name
        case streamIcon = "stream_icon"
        case categoryID = "category_id"
        case containerExtension =
            "container_extension"
    }
}

// MARK: - Errors

enum XtreamError: LocalizedError {
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

        case .httpError(let statusCode):
            return "De Xtream-server gaf HTTP-status \(statusCode)."

        case .decodingFailed:
            return "Het antwoord van de Xtream-server kon niet worden verwerkt."
        }
    }
}
