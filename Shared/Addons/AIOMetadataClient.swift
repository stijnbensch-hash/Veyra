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
        return try await meta(type: type, id: imdbID)
    }

    /// Reparatie Fase 2 (A/B-testrapport §17/§35): live getest blijkt deze addon ook
    /// `tmdb:{id}`-prefixen te accepteren (zie `manifest.idPrefixes`) -- hiermee kan
    /// AIOMetadata ook bevraagd worden voor titels ZONDER IMDb-ID (bv. Château
    /// Planckaert), wat voorheen altijd `nil` opleverde omdat alleen op imdbID
    /// gezocht werd.
    func meta(type: String, tmdbID: Int) async throws -> AIOMetaItem? {
        try await meta(type: type, id: "tmdb:\(tmdbID)")
    }

    private func meta(type: String, id: String) async throws -> AIOMetaItem? {
        guard !id.isEmpty else { return nil }
        let path = "meta/\(type)/\(id).json"
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

    // Reparatie Fase 2 (A/B-testrapport §27/§35): live audit van de echte addon-
    // respons toonde dat deze velden al meegeleverd worden maar voorheen nergens
    // gedecodeerd/gebruikt werden -- genre/score/ClearLogo/episodelijst gingen zo
    // verloren t.o.v. wat TMDB-aanroepen elders in Veyra wél opleveren.
    var genres: [String]?
    var imdbRating: Double?
    var logo: String?
    var runtime: String?
    var videos: [AIOMetaVideo]?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case poster
        case background
        case description
        case releaseInfo
        case imdbID = "imdb_id"
        case genres
        case imdbRating
        case logo
        case runtime
        case videos
    }

    /// Bugfix (gevonden via de nieuwe Diagnostics-screen, §73): het Fase 2 A/B-testrapport had
    /// `imdbRating` als `Double` geverifieerd, maar dat gebeurde toen door de ruwe JSON met Python
    /// te parsen -- nooit via deze eigen `Decodable`-struct. De live addon levert dit veld altijd
    /// als STRING (bv. `"6.1"`), nooit als getal. `JSONDecoder` liet daardoor de VOLLEDIGE decode
    /// falen bij een type-mismatch, en omdat `MetadataRepository.aioMeta` dat met `try?` opving,
    /// viel AIOMetadata sindsdien stil altijd terug op TMDB -- voor metadata én artwork, voor elke
    /// titel. Vandaar een eigen `init(from:)` die zowel string als getal accepteert i.p.v. de
    /// gesynthetiseerde decoder die op het eerste type-verschil meteen alles laat mislukken.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        poster = try container.decodeIfPresent(String.self, forKey: .poster)
        background = try container.decodeIfPresent(String.self, forKey: .background)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        releaseInfo = try container.decodeIfPresent(String.self, forKey: .releaseInfo)
        imdbID = try container.decodeIfPresent(String.self, forKey: .imdbID)
        genres = try container.decodeIfPresent([String].self, forKey: .genres)
        logo = try container.decodeIfPresent(String.self, forKey: .logo)
        runtime = try container.decodeIfPresent(String.self, forKey: .runtime)
        videos = try container.decodeIfPresent([AIOMetaVideo].self, forKey: .videos)

        if let ratingValue = try? container.decodeIfPresent(Double.self, forKey: .imdbRating) {
            imdbRating = ratingValue
        } else if let ratingString = try? container.decodeIfPresent(String.self, forKey: .imdbRating) {
            // `try?` op een al-Optional-teruggevende expressie plat zich sinds SE-0230 af tot één
            // optional -- `ratingString` is hier dus een gewone (niet-optionele) `String`, geen
            // `String?`. Vandaar rechtstreeks `Double(ratingString)` i.p.v. `.flatMap`, dat anders
            // naar `Sequence.flatMap` (over losse `Character`s) resolvet.
            imdbRating = Double(ratingString)
        } else {
            imdbRating = nil
        }
    }

    var resolvedImdbID: String? {
        if let imdbID, !imdbID.isEmpty { return imdbID }
        if let id, id.hasPrefix("tt") { return id }
        return nil
    }

    var posterURL: URL? { poster.flatMap { URL(string: $0) } }
    var backdropURL: URL? { background.flatMap { URL(string: $0) } }
    var logoURL: URL? { logo.flatMap { URL(string: $0) } }

    func mediaItem() -> MediaItem {
        MediaItem(
            title: name ?? "Onbekende titel",
            type: type == "series" ? .series : .movie,
            imdbID: resolvedImdbID,
            overview: description,
            releaseDate: releaseInfo,
            posterURL: posterURL,
            backdropURL: backdropURL,
            genre: genres?.first,
            rating: imdbRating,
            catalogItemID: id
        )
    }
}

/// Eén aflevering uit de `videos`-array van een series-meta-respons (al in één
/// aanroep meegeleverd -- zie A/B-testrapport §27, geen apart seizoen-per-
/// seizoen-verzoek nodig zoals bij TMDB).
struct AIOMetaVideo: Decodable, Hashable {
    var id: String?
    var title: String?
    var season: Int?
    var episode: Int?
    var overview: String?
    var released: String?
    var thumbnail: String?
    var runtime: String?
    var available: Bool?

    var thumbnailURL: URL? { thumbnail.flatMap { URL(string: $0) } }
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
