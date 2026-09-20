import Foundation

/// Haalt `manifest.json` op van een Stremio-compatibele addon (AIOStreams,
/// AIOMetadata, Torrentio, enz.) en leidt daaruit de naam en het soort addon
/// af — zie de officiële spec:
/// https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/api/responses/manifest.md
///
/// Elke addon beschrijft zelf, via `resources`, wat hij levert ("stream",
/// "meta", "catalog", …). Een addon die "meta" en/of "catalog" aanbiedt is
/// een metadata-addon (zoals AIOMetadata); anders — typisch enkel
/// "stream" — is het een streaming-addon (zoals AIOStreams). Er is dus geen
/// reden om de gebruiker zelf een type te laten kiezen.
enum StremioManifestFetcher {
    struct FetchedManifest {
        let name: String
        let kind: AddonKind
    }

    enum FetchError: LocalizedError, Equatable {
        case invalidURL
        case network(String)
        case invalidResponse
        case notAManifest

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Voer een geldige addon-URL in."
            case .network(let message):
                return "Kon het manifest niet ophalen: \(message)"
            case .invalidResponse:
                return "De addon gaf geen geldig antwoord terug."
            case .notAManifest:
                return "Deze URL lijkt geen geldige Stremio-addon (manifest.json) te zijn."
            }
        }
    }

    static func fetch(
        from url: URL,
        session: URLSession = .shared
    ) async throws -> FetchedManifest {
        let manifestURL = manifestJSONURL(for: url)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: manifestURL)
        } catch {
            throw FetchError.network(error.localizedDescription)
        }

        guard
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode)
        else {
            throw FetchError.invalidResponse
        }

        guard
            let manifest = try? JSONDecoder().decode(StremioManifestPayload.self, from: data),
            !manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw FetchError.notAManifest
        }

        let resourceNames = Set(
            (manifest.resources ?? []).map { $0.resourceName.lowercased() }
        )

        // "stream" wint altijd: een addon die streams levert is een
        // streaming-addon voor Veyra, ook als hij daarnaast (zoals
        // AIOStreams) ook "catalog" of "meta" aanbiedt voor zijn eigen
        // zoek-/configuratiescherm. Enkel zónder "stream" — typisch enkel
        // "meta"/"catalog", zoals Cinemeta of AIOMetadata — is het een
        // metadata-addon.
        let kind: AddonKind
        if resourceNames.contains("stream") {
            kind = .aioStreams
        } else if resourceNames.contains("meta") || resourceNames.contains("catalog") {
            kind = .aioMetadata
        } else {
            kind = .aioStreams
        }

        return FetchedManifest(
            name: manifest.name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind
        )
    }

    /// Addons worden meestal geplakt als de kale basis-URL, maar soms ook
    /// met "manifest.json" er al achteraan (bv. rechtstreeks gekopieerd uit
    /// Stremio zelf) — beide moeten werken.
    private static func manifestJSONURL(for url: URL) -> URL {
        if url.lastPathComponent.lowercased() == "manifest.json" {
            return url
        }
        return url.appendingPathComponent("manifest.json")
    }
}

/// Rauwe `manifest.json`-payload — enkel de velden die we nodig hebben om
/// naam en soort af te leiden; de rest van de Stremio-spec (catalogs,
/// idPrefixes, ...) is hier niet relevant.
private struct StremioManifestPayload: Decodable {
    let name: String
    let resources: [StremioManifestResource]?
}

/// `resources` in een Stremio-manifest is een lijst van ofwel losse
/// strings (`"stream"`) ofwel objecten (`{"name": "stream", "types": [...]}`)
/// — deze decodeert beide vormen naar dezelfde naam.
private enum StremioManifestResource: Decodable {
    case plain(String)
    case detailed(name: String)

    var resourceName: String {
        switch self {
        case .plain(let name): return name
        case .detailed(let name): return name
        }
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
            let name = try? container.decode(String.self)
        {
            self = .plain(name)
            return
        }

        struct DetailedResource: Decodable {
            let name: String
        }

        let detailed = try DetailedResource(from: decoder)
        self = .detailed(name: detailed.name)
    }
}
