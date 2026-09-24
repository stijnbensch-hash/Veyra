import Foundation

struct AIOStreamsProvider:
    ResolvedMediaSourceProvider
{
    let name = "AIOStreams"

    let baseURL: URL

    private let session:
        URLSession

    init(
        baseURL: URL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Normale MediaSourceProvider-route

    func sources(
        for item: MediaItem
    ) async throws -> [PlayableSource] {
        try await resolvedSources(
            for: item
        )
        .map(\.source)
    }

    // MARK: - Bronnen met originele addon-naam

    func resolvedSources(
        for item: MediaItem
    ) async throws -> [ResolvedSource] {
        guard
            let imdbID = item.imdbID,
            !imdbID.isEmpty
        else {
            return []
        }

        let mediaType:
            String

        let mediaID:
            String

        switch item.type {
        case .movie:
            mediaType = "movie"
            mediaID = imdbID

        case .series:
            guard
                let seasonNumber =
                    item.seasonNumber,
                let episodeNumber =
                    item.episodeNumber
            else {
                return []
            }

            mediaType = "series"

            mediaID =
                "\(imdbID):\(seasonNumber):\(episodeNumber)"

        case .liveTV, .iptvSeries:
            return []
        }

        let streamURL =
            baseURL
                .appendingPathComponent(
                    "stream"
                )
                .appendingPathComponent(
                    mediaType
                )
                .appendingPathComponent(
                    "\(mediaID).json"
                )

        let (data, response) =
            try await session.data(
                from: streamURL
            )

        try Task.checkCancellation()

        guard
            let httpResponse =
                response
                    as? HTTPURLResponse
        else {
            throw
                AIOStreamsError
                    .invalidResponse
        }

        guard
            (200...299).contains(
                httpResponse.statusCode
            )
        else {
            throw
                AIOStreamsError
                    .httpError(
                        statusCode:
                            httpResponse
                                .statusCode
                    )
        }

        let responseValue:
            AIOStreamsStreamResponse

        do {
            responseValue =
                try JSONDecoder()
                    .decode(
                        AIOStreamsStreamResponse
                            .self,
                        from: data
                    )
        } catch {
            throw
                AIOStreamsError
                    .decodingFailed
        }

        var result:
            [ResolvedSource] = []

        for stream
            in responseValue.streams
        {
            try Task.checkCancellation()

            guard
                let urlString =
                    stream.url?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ),
                !urlString.isEmpty,
                let url =
                    URL(
                        string:
                            urlString
                    ),
                let scheme =
                    url.scheme?
                        .lowercased(),
                scheme == "https"
                    || scheme == "http"
            else {
                continue
            }

            let playableSource =
                PlayableSource(
                    name:
                        stream.displayName,
                    description:
                        stream
                            .normalizedDescription,
                    metadata:
                        AIOStreamsMetadataParser
                            .parse(
                                name:
                                    stream
                                        .displayName,
                                description:
                                    stream
                                        .normalizedDescription
                            ),
                    url:
                        url,
                    kind:
                        .direct,
                    requiresSoftwareVideo:
                        false
                )

            result.append(
                ResolvedSource(
                    source:
                        playableSource,

                    // Dit is bewust NIET
                    // "AIOStreams".
                    //
                    // De echte naam komt uit
                    // stream.name in de JSON.
                    originName:
                        stream.originName
                            ?? name
                )
            )
        }

        return result
    }
}

// MARK: - Response

private struct AIOStreamsStreamResponse:
    Decodable
{
    let streams:
        [AIOStreamsStream]
}

private struct AIOStreamsStream:
    Decodable
{
    let name:
        String?

    let title:
        String?

    let description:
        String?

    let url:
        String?

    // Naam voor de filterknop.
    //
    // Exact zoals de addon hem terugstuurt,
    // alleen omliggende whitespace wordt
    // verwijderd.
    var originName:
        String?
    {
        normalized(
            name
        )
    }

    // Zichtbare titel van de individuele
    // stream blijft losstaan van de
    // filtercategorie.
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

        return
            "Mediabron"
    }

    var normalizedDescription:
        String?
    {
        normalized(
            description
        )
    }

    private func normalized(
        _ value:
            String?
    ) -> String? {
        guard
            let value
        else {
            return nil
        }

        let result =
            value.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        return
            result.isEmpty
                ? nil
                : result
    }
}

// MARK: - Errors

enum AIOStreamsError:
    LocalizedError
{
    case invalidResponse

    case httpError(
        statusCode: Int
    )

    case decodingFailed

    var errorDescription:
        String?
    {
        switch self {
        case .invalidResponse:
            return
                "AIOStreams gaf een ongeldig antwoord."

        case .httpError(
            let statusCode
        ):
            return
                "AIOStreams gaf HTTP \(statusCode)."

        case .decodingFailed:
            return
                "Het AIOStreams-antwoord kon niet worden verwerkt."
        }
    }
}
