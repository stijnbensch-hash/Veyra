import Foundation

struct AIOStreamsProvider: MediaSourceProvider {
    let name = "AIOStreams"

    let baseURL: URL

    func sources(for item: MediaItem) async throws -> [PlayableSource] {
        guard let imdbID = item.imdbID else {
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

        let (data, response) = try await URLSession.shared.data(
            from: streamURL
        )

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIOStreamsError.invalidResponse
        }

        let result = try JSONDecoder().decode(
            AIOStreamsStreamResponse.self,
            from: data
        )

        return result.streams.compactMap { stream in
            guard let urlString = stream.url,
                  let url = URL(string: urlString) else {
                return nil
            }

            return PlayableSource(
                name: stream.displayName,
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
    let url: String?

    var displayName: String {
        if let title, !title.isEmpty {
            return title
        }

        if let name, !name.isEmpty {
            return name
        }

        return "AIOStreams Source"
    }
}

enum AIOStreamsError: Error {
    case invalidResponse
}
