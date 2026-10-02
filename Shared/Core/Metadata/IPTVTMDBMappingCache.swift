import Foundation

/// Fase 9 (TMDB-spec, IPTV-mapping §50/§51/§52): persistente cache van IMDb-ID of titel+jaar
/// naar TMDB-ID, voor IPTV/VOD-bronnen zonder eigen TMDB-ID (addon-catalogi, mediaservers zonder
/// `ProviderIds`). Spec §50: "niet elke appstart dezelfde VOD-film opnieuw searchen op TMDB als
/// mapping al bekend is" -- daarom in `UserDefaults` i.p.v. enkel in-memory: de bestaande
/// session-only caches (`TMDBMetadataCache`/`TMDBSearchCache`) legen bij elke herstart en lossen
/// dit dus niet op. Zelfde opslagpatroon als `ChannelLogoOverrideStore` (JSON-dictionary in
/// UserDefaults).
///
/// Succesvolle mappings blijven langdurig geldig (een titel/IMDb-ID verandert niet van TMDB-ID).
/// Negatieve/ambigue mappings (spec §51: "ook negatieve/ambigue mappings kort cachen") krijgen
/// een kortere TTL, zodat een structureel onvindbare titel niet bij elke catalogusverversing
/// opnieuw gezocht wordt, maar een later alsnog gevonden match niet voorgoed gemist blijft.
actor IPTVTMDBMappingCache {
    static let shared = IPTVTMDBMappingCache()

    private struct Entry: Codable {
        let tmdbID: Int?
        let cachedAt: Date
    }

    private static let defaultsKey = "veyra.iptv.tmdbMapping"
    private static let negativeTTL: TimeInterval = 7 * 24 * 60 * 60

    private var entries: [String: Entry] = [:]
    private var didLoad = false

    private init() {}

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let dict = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return
        }
        entries = dict
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    private func key(imdbID: String?, title: String, year: Int?, kind: ShelfMediaKind) -> String {
        if let imdbID, !imdbID.isEmpty {
            return "imdb:\(imdbID):\(kind.rawValue)"
        }
        let normalized = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "title:\(normalized):\(year.map(String.init) ?? "-"):\(kind.rawValue)"
    }

    /// `.some(.some(id))` = bekende, geldige positieve mapping (direct gebruiken, spec §52: geen
    /// nieuwe title search); `.some(nil)` = bekende, nog geldige negatieve/ambigue mapping (niet
    /// opnieuw zoeken); `nil` = nog niet (geldig) bekend, moet opgezocht worden.
    func cachedTMDBID(imdbID: String?, title: String, year: Int?, kind: ShelfMediaKind) -> Int?? {
        loadIfNeeded()
        let k = key(imdbID: imdbID, title: title, year: year, kind: kind)
        guard let entry = entries[k] else { return nil }
        if entry.tmdbID == nil, Date().timeIntervalSince(entry.cachedAt) > Self.negativeTTL {
            entries[k] = nil
            return nil
        }
        return .some(entry.tmdbID)
    }

    func store(tmdbID: Int?, imdbID: String?, title: String, year: Int?, kind: ShelfMediaKind) {
        loadIfNeeded()
        let k = key(imdbID: imdbID, title: title, year: year, kind: kind)
        entries[k] = Entry(tmdbID: tmdbID, cachedAt: Date())
        persist()
    }
}
