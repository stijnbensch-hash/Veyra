import Foundation

struct StremioAddonProvider:
    ResolvedMediaSourceProvider
{
    let name: String
    let baseURL: URL

    private let session: URLSession

    init(
        name: String,
        baseURL: URL,
        session: URLSession = .shared
    ) {
        let cleanedName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        self.name =
            cleanedName.isEmpty
                ? "Stremio Addon"
                : cleanedName

        self.baseURL =
            Self.normalizedBaseURL(
                baseURL
            )

        self.session = session
    }

    // MARK: - MediaSourceProvider

    func sources(
        for item: MediaItem
    ) async throws -> [PlayableSource] {
        try await resolvedSources(
            for: item
        )
        .map(\.source)
    }

    // MARK: - ResolvedMediaSourceProvider

    func resolvedSources(
        for item: MediaItem
    ) async throws -> [ResolvedSource] {
        guard
            let imdbID =
                item.imdbID?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
            !imdbID.isEmpty
        else {
            debug(
                "Geen IMDb-ID beschikbaar."
            )

            return []
        }

        guard
            let requestInfo =
                streamRequest(
                    item: item,
                    imdbID: imdbID
                )
        else {
            debug(
                "Geen geldige streamrequest voor dit MediaItem."
            )

            return []
        }

        let streamURL =
            baseURL
                .appendingPathComponent(
                    "stream"
                )
                .appendingPathComponent(
                    requestInfo.type
                )
                .appendingPathComponent(
                    "\(requestInfo.id).json"
                )

        debug(
            "REQUEST \(streamURL.absoluteString)"
        )

        var request =
            URLRequest(
                url: streamURL
            )

        request.timeoutInterval = 30

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let data: Data
        let response: URLResponse

        do {
            (
                data,
                response
            ) =
                try await session.data(
                    for: request
                )
        } catch {
            debug(
                "NETWERKFOUT: \(error.localizedDescription)"
            )

            throw error
        }

        try Task.checkCancellation()

        guard
            let http =
                response as? HTTPURLResponse
        else {
            debug(
                "Geen HTTPURLResponse."
            )

            throw StremioAddonError
                .invalidResponse
        }

        debug(
            "HTTP \(http.statusCode) · \(data.count) bytes"
        )

        guard
            (200...299).contains(
                http.statusCode
            )
        else {
            debugResponseBody(
                data
            )

            throw StremioAddonError
                .httpError(
                    http.statusCode
                )
        }

        let decoded:
            StremioStreamResponse

        do {
            decoded =
                try JSONDecoder()
                    .decode(
                        StremioStreamResponse.self,
                        from: data
                    )
        } catch {
            debug(
                "DECODEFOUT: \(error)"
            )

            debugResponseBody(
                data
            )

            throw StremioAddonError
                .decodingFailed(
                    error
                )
        }

        debug(
            "Aantal streams: \(decoded.streams.count)"
        )

        var directCount = 0
        var torrentCount = 0
        var externalCount = 0
        var unknownCount = 0

        var result:
            [ResolvedSource] = []

        var seenURLs =
            Set<String>()

        for (
            index,
            stream
        ) in decoded.streams.enumerated() {
            try Task.checkCancellation()

            let hasDirectURL =
                stream.normalizedURL != nil

            let hasTorrent =
                stream.normalizedInfoHash != nil

            let hasExternal =
                stream.normalizedExternalURL != nil

            if hasDirectURL {
                directCount += 1
            }

            if hasTorrent {
                torrentCount += 1
            }

            if hasExternal {
                externalCount += 1
            }

            if !hasDirectURL
                && !hasTorrent
                && !hasExternal
            {
                unknownCount += 1
            }

            debug(
                """
                STREAM \(index + 1):
                name=\(stream.name ?? "nil")
                title=\(stream.title ?? "nil")
                url=\(hasDirectURL ? "ja" : "nee")
                externalUrl=\(hasExternal ? "ja" : "nee")
                infoHash=\(hasTorrent ? "ja" : "nee")
                fileIdx=\(stream.fileIdx.map(String.init) ?? "nil")
                """
            )

            guard
                let source =
                    playableHTTPSource(
                        stream
                    )
            else {
                continue
            }

            guard
                seenURLs.insert(
                    source.url.absoluteString
                ).inserted
            else {
                continue
            }

            result.append(
                ResolvedSource(
                    source: source,
                    originName: name
                )
            )
        }

        debug(
            """
            SAMENVATTING:
            totaal=\(decoded.streams.count)
            direct=\(directCount)
            torrent=\(torrentCount)
            external=\(externalCount)
            onbekend=\(unknownCount)
            playable=\(result.count)
            """
        )

        return result
    }

    // MARK: - Request

    private func streamRequest(
        item: MediaItem,
        imdbID: String
    ) -> (
        type: String,
        id: String
    )? {
        switch item.type {
        case .movie:
            return (
                type: "movie",
                id: imdbID
            )

        case .series:
            guard
                let season =
                    item.seasonNumber,
                let episode =
                    item.episodeNumber
            else {
                return nil
            }

            return (
                type: "series",
                id:
                    "\(imdbID):\(season):\(episode)"
            )

        case .liveTV:
            return nil
        }
    }

    // MARK: - Direct streams

    private func playableHTTPSource(
        _ stream: StremioStream
    ) -> PlayableSource? {
        guard
            let string =
                stream.normalizedURL,
            let url =
                URL(
                    string: string
                ),
            let scheme =
                url.scheme?
                    .lowercased(),
            scheme == "https"
                || scheme == "http"
        else {
            return nil
        }

        return PlayableSource(
            name:
                stream.displayName,
            description:
                stream.displayDescription,
            metadata:
                AIOStreamsMetadataParser
                    .parse(
                        name:
                            stream.displayName,
                        description:
                            stream.displayDescription
                    ),
            url:
                url,
            kind:
                .direct,
            requiresSoftwareVideo:
                false
        )
    }

    // MARK: - Base URL

    private static func normalizedBaseURL(
        _ url: URL
    ) -> URL {
        var result = url

        while
            result.lastPathComponent
                .lowercased()
                == "manifest.json"
        {
            result.deleteLastPathComponent()
        }

        return result
    }

    // MARK: - Debug

    private func debug(
        _ message: String
    ) {
        #if DEBUG
        print(
            "[StremioAddonProvider][\(name)] \(message)"
        )
        #endif
    }

    private func debugResponseBody(
        _ data: Data
    ) {
        #if DEBUG
        guard
            let body =
                String(
                    data: data,
                    encoding: .utf8
                )
        else {
            print(
                "[StremioAddonProvider][\(name)] Response is geen UTF-8."
            )

            return
        }

        let limited =
            String(
                body.prefix(
                    4_000
                )
            )

        print(
            "[StremioAddonProvider][\(name)] RESPONSE BODY:\n\(limited)"
        )
        #endif
    }
}

// MARK: - Response

private struct StremioStreamResponse:
    Decodable
{
    let streams:
        [StremioStream]
}

private struct StremioStream:
    Decodable
{
    let name: String?
    let title: String?
    let description: String?

    let url: String?
    let externalUrl: String?

    let infoHash: String?
    let fileIdx: Int?

    let behaviorHints:
        BehaviorHints?

    struct BehaviorHints:
        Decodable
    {
        let bingeGroup: String?
        let notWebReady: Bool?
        let filename: String?
        let videoSize: Int64?
    }

    var normalizedURL:
        String?
    {
        normalized(
            url
        )
    }

    var normalizedExternalURL:
        String?
    {
        normalized(
            externalUrl
        )
    }

    var normalizedInfoHash:
        String?
    {
        normalized(
            infoHash
        )
    }

    var displayName:
        String
    {
        if let title =
            normalized(
                title
            )
        {
            return title
        }

        if let name =
            normalized(
                name
            )
        {
            return name
        }

        if let filename =
            normalized(
                behaviorHints?.filename
            )
        {
            return filename
        }

        if normalizedInfoHash != nil {
            return "Torrent"
        }

        return "Mediabron"
    }

    var displayDescription:
        String?
    {
        var values:
            [String] = []

        if let description =
            normalized(
                description
            )
        {
            values.append(
                description
            )
        }

        if
            let size =
                behaviorHints?
                    .videoSize,
            size > 0
        {
            let formatter =
                ByteCountFormatter()

            formatter.countStyle =
                .file

            values.append(
                formatter.string(
                    fromByteCount:
                        size
                )
            )
        }

        if normalizedInfoHash != nil {
            values.append(
                "Torrent"
            )
        }

        guard
            !values.isEmpty
        else {
            return nil
        }

        return values.joined(
            separator: " · "
        )
    }

    private func normalized(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let cleaned =
            value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return cleaned.isEmpty
            ? nil
            : cleaned
    }
}

// MARK: - Errors

enum StremioAddonError:
    LocalizedError
{
    case invalidResponse
    case httpError(Int)
    case decodingFailed(Error)

    var errorDescription:
        String?
    {
        switch self {
        case .invalidResponse:
            return
                "De addon gaf een ongeldig antwoord."

        case .httpError(
            let statusCode
        ):
            return
                "De addon gaf HTTP-status \(statusCode)."

        case .decodingFailed:
            return
                "Het streamantwoord van de addon kon niet worden verwerkt."
        }
    }
}
