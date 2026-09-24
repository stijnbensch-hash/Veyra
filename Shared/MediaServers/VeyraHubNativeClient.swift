import Foundation

/// Calls Veyra Hub's own native REST API (`/api/v1/...`) directly by IMDb
/// id, instead of going through the Jellyfin-compatibility bridge.
///
/// The Jellyfin bridge (`JellyfinService`) can only resolve a title to a hub
/// item id by searching addon catalogs first — which only works for addons
/// that expose a searchable catalog. Most stream-only Stremio-style addons
/// (Torrentio, MediaFusion, AIOStreams-type addons) never do: they only
/// implement the `stream` resource and expect to be asked directly by IMDb
/// id. Veyra Hub's native API supports exactly that, following the same
/// "imdbID" / "imdbID:season:episode" id convention already used by
/// `StremioAddonProvider`, `AIOStreamsProvider` and `TorrentProvider`
/// elsewhere in the app. The session access token from Jellyfin login
/// already works as this API's Bearer token too (same server-side session),
/// so no separate sign-in is needed.
struct VeyraHubNativeClient {
    let account: MediaServerAccount

    private let session: URLSession

    init(
        account: MediaServerAccount,
        session: URLSession = .shared
    ) {
        self.account = account
        self.session = session
    }

    // MARK: - Models

    /// Mirrors VeyraHub's `HubStream` JSON shape exactly (same field names),
    /// returned by both the Jellyfin bridge and the native API.
    struct NativeStream: Decodable, Hashable {
        let addonID: String
        let addonName: String
        let name: String?
        let title: String?
        let description: String?
        let url: String
        let filename: String?
        let videoSize: Int64?
    }

    /// Mirrors VeyraHub's `HubSubtitle` JSON shape.
    struct NativeSubtitle: Decodable, Hashable {
        let addonID: String
        let addonName: String
        let lang: String?
        let name: String?
        let url: String
    }

    private struct StreamsResponse: Decodable {
        let streams: [NativeStream]
    }

    private struct SubtitlesResponse: Decodable {
        let subtitles: [NativeSubtitle]
    }

    // MARK: - Lookup id

    /// Builds the id VeyraHub's native API expects for a media item: the
    /// plain IMDb id for a movie, or "imdbID:season:episode" for an
    /// episode. Falls back to the item's own `catalogItemID` when there's
    /// no IMDb id — e.g. a live sports event from an addon like
    /// SeriousSportSync, which VeyraHub's `/api/v1/items/.../streams`
    /// aggregation happily accepts (it just forwards whatever id it's
    /// given to each addon's own `stream` endpoint; it doesn't require an
    /// IMDb-shaped id). Without this fallback such items never even reach
    /// that endpoint, so VeyraHub never calls the addon at all. Returns nil
    /// only when neither id is available (or a series item is missing
    /// season/episode).
    static func nativeMediaID(for item: MediaItem) -> String? {
        let imdbID =
            item.imdbID?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        let catalogItemID =
            item.catalogItemID?
                .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let id =
                [imdbID, catalogItemID]
                    .compactMap({ $0 })
                    .first(where: { !$0.isEmpty })
        else {
            return nil
        }

        switch item.type {
        case .movie:
            return id

        case .series:
            guard
                let season = item.seasonNumber,
                let episode = item.episodeNumber
            else {
                return nil
            }

            return "\(id):\(season):\(episode)"

        case .liveTV, .iptvSeries:
            return nil
        }
    }

    // MARK: - Requests

    func streams(
        type: MediaType,
        id: String
    ) async throws -> [NativeStream] {
        let data =
            try await get(
                nativeType(type),
                id,
                "streams"
            )

        return try JSONDecoder()
            .decode(
                StreamsResponse.self,
                from: data
            )
            .streams
    }

    func subtitles(
        type: MediaType,
        id: String
    ) async throws -> [NativeSubtitle] {
        let data =
            try await get(
                nativeType(type),
                id,
                "subtitles"
            )

        return try JSONDecoder()
            .decode(
                SubtitlesResponse.self,
                from: data
            )
            .subtitles
    }

    // MARK: - Networking

    private func nativeType(
        _ type: MediaType
    ) -> String {
        type == .series ? "series" : "movie"
    }

    private func get(
        _ pathComponents: String...
    ) async throws -> Data {
        var url =
            account.serverURL
                .appendingPathComponent("api")
                .appendingPathComponent("v1")
                .appendingPathComponent("items")

        for component in pathComponents {
            url = url.appendingPathComponent(component)
        }

        var request = URLRequest(url: url)

        request.setValue(
            "Bearer \(account.accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) =
            try await session.data(for: request)

        guard
            let httpResponse =
                response as? HTTPURLResponse
        else {
            throw VeyraHubNativeClientError
                .invalidResponse
        }

        guard
            (200...299)
                .contains(
                    httpResponse.statusCode
                )
        else {
            throw VeyraHubNativeClientError
                .server(
                    httpResponse.statusCode
                )
        }

        return data
    }
}

enum VeyraHubNativeClientError: LocalizedError {
    case invalidResponse
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Veyra Hub gaf een ongeldig antwoord."

        case .server(let code):
            return "Veyra Hub reageerde met een fout (\(code))."
        }
    }
}
