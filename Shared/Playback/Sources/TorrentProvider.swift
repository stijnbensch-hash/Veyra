import Foundation

struct TorrentProvider:
    MediaSourceProvider
{
    let name = "Torrent"

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

    // MARK: - MediaSourceProvider

    func sources(
        for item: MediaItem
    ) async throws -> [PlayableSource] {
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

        // Bouw de torrent stream URL
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

        // Haal de torrent streams op
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
                TorrentProviderError
                    .invalidResponse
        }

        guard
            (200...299).contains(
                httpResponse.statusCode
            )
        else {
            throw
                TorrentProviderError
                    .httpError(
                        httpResponse.statusCode
                    )
        }

        // Decode de torrent response
        let streamResponse:
            TorrentStreamResponse

        do {
            streamResponse =
                try JSONDecoder()
                    .decode(
                        TorrentStreamResponse
                            .self,
                        from: data
                    )
        } catch {
            throw
                TorrentProviderError
                    .decodingFailed(
                        error
                    )
        }

        // Converteer naar PlayableSource
        return streamResponse
            .streams
            .compactMap { stream -> PlayableSource? in
                guard
                    let url =
                        URL(
                            string:
                                stream.url
                        ),
                    let scheme = url.scheme?.lowercased(),
                    scheme == "https" || scheme == "http"
                else {
                    return nil
                }

                return PlayableSource(
                    name:
                        stream.name
                            ?? stream.title
                            ?? "Torrent",
                    description:
                        formatDescription(
                            stream
                        ),
                    url: url,
                    kind: .direct
                )
            }
    }

    // MARK: - Helpers

    private func formatDescription(
        _ stream:
            TorrentStreamItem
    ) -> String? {
        var parts:
            [String] = []

        // Voeg kwaliteit toe
        if let quality =
            stream.quality
        {
            parts.append(
                quality
            )
        }

        // Voeg bestandsgrootte toe
        if let size =
            stream.size
        {
            parts.append(
                formatFileSize(
                    size
                )
            )
        }

        // Voeg seeders toe
        if let seeders =
            stream.seeders
        {
            parts.append(
                "\(seeders) seeders"
            )
        }

        return parts
            .isEmpty
            ? nil
            : parts.joined(
                separator:
                    " · "
            )
    }

    private func formatFileSize(
        _ bytes: Int64
    ) -> String {
        let formatter =
            ByteCountFormatter()

        formatter.countStyle =
            .file

        return formatter.string(
            fromByteCount:
                bytes
        )
    }
}

// MARK: - Response Models

private struct TorrentStreamResponse:
    Decodable
{
    let streams:
        [TorrentStreamItem]
}

private struct TorrentStreamItem:
    Decodable
{
    let name: String?
    let title: String?
    let url: String
    let quality: String?
    let size: Int64?
    let seeders: Int?

    enum CodingKeys:
        String,
        CodingKey
    {
        case name
        case title
        case url
        case quality
        case size
        case seeders
    }
}

// MARK: - Errors

enum TorrentProviderError:
    LocalizedError
{
    case invalidResponse
    case httpError(Int)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "De torrent addon gaf een ongeldig antwoord."

        case .httpError(
            let statusCode
        ):
            return "De torrent addon gaf HTTP-status \(statusCode)."

        case .decodingFailed:
            return "Het antwoord van de torrent addon kon niet worden verwerkt."
        }
    }
}
