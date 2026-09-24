import Foundation

/// Client voor een Stremio-compatibele metadata-addon zoals AIOMetadata:
/// dezelfde `manifest.json` / `catalog/{type}/{id}.json` / `meta/{type}/{id}.json`
/// conventie die de app al gebruikt voor streaming-addons (zie
/// `StremioAddonProvider`), maar dan voor catalogi en metadata i.p.v. streams.
struct AIOMetadataClient {
    let baseURL: URL

    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = Self.normalizedBaseURL(baseURL)
        self.session = session
    }

    private static func normalizedBaseURL(_ url: URL) -> URL {
        var string = url.absoluteString
        while string.hasSuffix("/") { string.removeLast() }
        if string.hasSuffix("manifest.json") {
            string.removeLast("manifest.json".count)
            while string.hasSuffix("/") { string.removeLast() }
        }
        return URL(string: string) ?? url
    }

    func manifest() async throws -> AIOMetadataManifest {
        try await request(path: "manifest.json")
    }

    func catalog(type: String, catalogID: String) async throws -> [AIOMetaItem] {
        let path = "catalog/\(type)/\(catalogID).json"
        let response: AIOMetadataCatalogResponse = try await request(path: path)
        return response.metas
    }

    func meta(type: String, imdbID: String) async throws -> AIOMetaItem? {
        guard !imdbID.isEmpty else { return nil }
        let path = "meta/\(type)/\(imdbID).json"
        let response: AIOMetadataMetaResponse = try await request(path: path)
        return response.meta
    }

    private func request<Response: Decodable>(path: String) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIOMetadataError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIOMetadataError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw AIOMetadataError.httpError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw AIOMetadataError.decodingFailed
        }
    }
}

struct AIOMetadataManifest: Decodable {
    var id: String?
    var name: String?
    var catalogs: [AIOMetadataCatalog]?
}

struct AIOMetadataCatalog: Decodable, Hashable {
    var type: String
    var id: String
    var name: String?

    var uniqueID: String { "\(type):\(id)" }
    var displayName: String { name ?? id }
}

private struct AIOMetadataCatalogResponse: Decodable {
    var metas: [AIOMetaItem]
}

private struct AIOMetadataMetaResponse: Decodable {
    var meta: AIOMetaItem
}

/// Eén item uit een Stremio-achtige catalogus- of meta-respons.
struct AIOMetaItem: Decodable, Hashable {
    var id: String?
    var type: String?
    var name: String?
    var poster: String?
    var background: String?
    var description: String?
    var releaseInfo: String?
    var imdbID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case poster
        case background
        case description
        case releaseInfo
        case imdbID = "imdb_id"
    }

    var resolvedImdbID: String? {
        if let imdbID, !imdbID.isEmpty { return imdbID }
        if let id, id.hasPrefix("tt") { return id }
        return nil
    }

    var posterURL: URL? { poster.flatMap { URL(string: $0) } }
    var backdropURL: URL? { background.flatMap { URL(string: $0) } }

    func mediaItem() -> MediaItem {
        MediaItem(
            title: name ?? "Onbekende titel",
            type: type == "series" ? .series : .movie,
            imdbID: resolvedImdbID,
            overview: description,
            releaseDate: releaseInfo,
            posterURL: posterURL,
            backdropURL: backdropURL,
            catalogItemID: id
        )
    }
}

enum AIOMetadataError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "De addon gaf een ongeldig antwoord."
        case .httpError(let code):
            return "De addon gaf HTTP \(code)."
        case .decodingFailed:
            return "De addon-gegevens konden niet worden verwerkt."
        case .network(let message):
            return message
        }
    }
}
