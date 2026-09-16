import Foundation

struct AIOStreamsProvider: MediaSourceProvider {
    let name = "AIOStreams"

    let baseURL: URL

    private let session: URLSession

    init(
        baseURL: URL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func sources(for item: MediaItem) async throws -> [PlayableSource] {
        guard
            let imdbID = item.imdbID,
            !imdbID.isEmpty
        else {
            return []
        }

        let mediaType: String

        switch item.type {
        case .movie:
            mediaType = "movie"

        case .series:
            mediaType = "series"

        case .liveTV:
            return []
        }

        let streamURL = baseURL
            .appendingPathComponent("stream")
            .appendingPathComponent(mediaType)
            .appendingPathComponent("\(imdbID).json")

        let (data, response) = try await session.data(
            from: streamURL
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIOStreamsError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIOStreamsError.httpError(
                statusCode: httpResponse.statusCode
            )
        }

        let result: AIOStreamsStreamResponse

        do {
            result = try JSONDecoder().decode(
                AIOStreamsStreamResponse.self,
                from: data
            )
        } catch {
            throw AIOStreamsError.decodingFailed
        }

        return result.streams.compactMap { stream in
            guard
                let urlString = stream.url,
                let url = URL(string: urlString),
                let scheme = url.scheme?.lowercased(),
                scheme == "https" || scheme == "http"
            else {
                return nil
            }

            return PlayableSource(
                name: stream.displayName,
                description: stream.normalizedDescription,
                url: url,
                kind: .direct
            )
        }
    }
}

private struct AIOStreamsStreamResponse: Decodable {
    let streams: [AIOStreamsStream]
}

private struct AIOStreamsStream: Decodable {
    let name: String?
    let title: String?
    let description: String?
    let url: String?

    var displayName: String {
        if let title = normalized(title) {
            return title
        }

        if let name = normalized(name) {
            return name
        }

        return "Media Source"
    }

    var normalizedDescription: String? {
        normalized(description)
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? nil : trimmed
    }
}

enum AIOStreamsError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The configured media provider returned an invalid response."

        case .httpError:
            return "The configured media provider could not complete the request."

        case .decodingFailed:
            return "The media provider response could not be processed."
        }
    }
}
