// VeyraBentoCatalog.swift
// Streamingdiensten en filmcollecties voor de bento-home (TMDB), plus het overzichtsscherm dat erbij hoort.

import SwiftUI
#if os(iOS)
import PhotosUI
#endif

// MARK: - Model

/// Een streamingdienst (logo) of een filmcollectie (poster) op de bento-home.
nonisolated struct BentoCatalog: Identifiable, Hashable, Sendable {
    nonisolated enum Source: Hashable, Sendable {
        case provider(Int)
        case collection(Int)
        case traktList(Int)
        /// Een catalogus van een geïnstalleerde addon (bv. AIOMetadata): addon-id, type (movie/series), catalogus-id.
        case addonCatalog(UUID, String, String)
    }

    let source: Source
    let name: String
    /// Vierkant logo (dienst) of landscape afbeelding (collectie).
    let imageURL: URL?
    /// Breed woordmerk van een streamingdienst (TMDB-netwerk), als dat bekend is.
    var wideURL: URL? = nil
    /// Merkkleur (0xRRGGBB) voor de kaart van een streamingdienst.
    var brand: UInt32? = nil
    /// Eigen logo van de gebruiker (wordt zoals het is getoond, niet wit ingekleurd).
    var customLogoURL: URL? = nil

    var id: String {
        switch source {
        case .provider(let value): return "p\(value)"
        case .collection(let value): return "c\(value)"
        case .traktList(let value): return "t\(value)"
        case .addonCatalog(let addon, let type, let catalog): return "a\(addon.uuidString)|\(type)|\(catalog)"
        }
    }

    /// Streamingdienst (TMDB of addon), in tegenstelling tot een collectie.
    var isService: Bool {
        switch source {
        case .provider, .addonCatalog: return true
        case .collection, .traktList: return false
        }
    }
}

nonisolated struct BentoCatalogSection: Identifiable, Sendable {
    let id: String
    let heading: String
    let titles: [BentoTMDBTitle]
}

/// Een collectie op Home: een TMDB-filmcollectie of een eigen Trakt-lijst, met optioneel eigen banner.
nonisolated struct BentoCollectionEntry: Codable, Hashable, Identifiable, Sendable {
    var id: String                // "c<tmdb-id>" of "t<trakt-lijst-id>"
    var name: String
    var imagePath: String?        // TMDB-pad, of een volledige URL
    var tmdbID: Int?
    var traktListID: Int?
    var traktSlug: String?
    var customImage: String?      // eigen banner: https-URL, of bestandsnaam van een eigen afbeelding

    private enum CodingKeys: String, CodingKey {
        case id, name, imagePath, tmdbID, traktListID, traktSlug, customImage
    }

    init(tmdbID: Int, name: String, imagePath: String?) {
        self.id = "c\(tmdbID)"
        self.name = name
        self.imagePath = imagePath
        self.tmdbID = tmdbID
    }

    init(traktListID: Int, slug: String, name: String) {
        self.id = "t\(traktListID)"
        self.name = name
        self.traktListID = traktListID
        self.traktSlug = slug
    }

    /// Leest ook de oudere opslag, waarin `id` het getal van de TMDB-collectie was.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        var tmdb = try container.decodeIfPresent(Int.self, forKey: .tmdbID)
        traktListID = try container.decodeIfPresent(Int.self, forKey: .traktListID)
        traktSlug = try container.decodeIfPresent(String.self, forKey: .traktSlug)
        customImage = try container.decodeIfPresent(String.self, forKey: .customImage)
        if let text = try? container.decode(String.self, forKey: .id) {
            id = text
        } else if let number = try? container.decode(Int.self, forKey: .id) {
            id = "c\(number)"
            if tmdb == nil { tmdb = number }
        } else {
            id = UUID().uuidString
        }
        tmdbID = tmdb
    }

    var isTraktList: Bool { traktListID != nil }

    var catalog: BentoCatalog {
        let source: BentoCatalog.Source
        if let traktListID {
            source = .traktList(traktListID)
        } else {
            source = .collection(tmdbID ?? 0)
        }
        return BentoCatalog(source: source, name: name, imageURL: VeyraCollectionsStore.imageURL(for: self))
    }
}

/// Bewaart de eigen lijst collecties. Geen lijst opgeslagen = de standaard franchises.
nonisolated enum VeyraCollectionsStore {
    private static let key = "veyra.bento.collections"

    static func load() -> [BentoCollectionEntry]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([BentoCollectionEntry].self, from: data)
    }

    static func save(_ entries: [BentoCollectionEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: Afbeeldingen

    static var imagesDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("VeyraCollectionBanners", isDirectory: true)
    }

    /// Bewaart een eigen afbeelding en geeft de bestandsnaam terug.
    static func saveImage(_ data: Data) -> String? {
        let directory = imagesDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    /// Eigen banner, anders de TMDB-afbeelding van de collectie.
    static func imageURL(for entry: BentoCollectionEntry) -> URL? {
        if let custom = entry.customImage, !custom.isEmpty {
            if custom.hasPrefix("http") { return URL(string: custom) }
            // Een eigen foto staat alleen op dit apparaat; elders (na sync) valt hij terug op de standaardbanner.
            let local = imagesDirectory.appendingPathComponent(custom)
            if FileManager.default.fileExists(atPath: local.path) { return local }
        }
        guard let path = entry.imagePath, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
    }
}

/// Eigen Trakt-lijsten, via dezelfde bron als de Planken.
@MainActor
enum VeyraTraktListSource {
    static func titles(listID: Int, kind: ShelfMediaKind) async -> [BentoTMDBTitle] {
        let shelf = Shelf(title: "", source: .trakt(list: .personal(id: listID, slug: "", name: ""), kind: kind))
        let items = await ShelfCatalogService.items(for: shelf)
        var result: [BentoTMDBTitle] = []
        for item in items {
            guard let id = item.tmdbID else { continue }
            result.append(BentoTMDBTitle(id: id, kind: kind == .movie ? .movie : .episode, title: item.title,
                                         posterURL: item.posterURL, backdropURL: item.backdropURL))
        }
        return result
    }

    static func personalLists() async -> [TraktPersonalList] {
        await ShelfCatalogService.fetchTraktPersonalLists()
    }
}

/// Catalogus van een addon (AIOMetadata e.d.), via dezelfde bron als de Planken.
@MainActor
enum VeyraAddonCatalogSource {
    static func titles(addonID: UUID, type: String, catalogID: String) async -> [BentoTMDBTitle] {
        let kind: ShelfMediaKind = type == "series" ? .series : .movie
        let shelf = Shelf(title: "", source: .addon(addonID: addonID, addonName: "", catalogType: type,
                                                    catalogID: catalogID, catalogName: ""))
        let items = await ShelfCatalogService.items(for: shelf)
        var result: [BentoTMDBTitle] = []
        for item in items {
            guard let id = item.tmdbID else { continue }
            result.append(BentoTMDBTitle(id: id, kind: kind == .movie ? .movie : .episode, title: item.title,
                                         posterURL: item.posterURL, backdropURL: item.backdropURL))
        }
        return result
    }
}

/// Een streamingdienst op Home: een TMDB-aanbieder of een addon-catalogus, met optioneel eigen logo.
nonisolated struct BentoStreamingEntry: Codable, Hashable, Identifiable, Sendable {
    var id: String                // "p<tmdb-provider-id>" of "a<addon>|<type>|<catalogus>"
    var name: String
    var providerID: Int?
    var logoPath: String?         // TMDB-pad van het standaardlogo
    var addonID: UUID?
    var catalogType: String?
    var catalogID: String?
    var customLogo: String?       // https-URL of bestandsnaam van een eigen afbeelding (alleen op dit apparaat)

    init(providerID: Int, name: String, logoPath: String?) {
        self.id = "p\(providerID)"
        self.name = name
        self.providerID = providerID
        self.logoPath = logoPath
    }

    init(addonID: UUID, catalogType: String, catalogID: String, name: String) {
        self.id = "a\(addonID.uuidString)|\(catalogType)|\(catalogID)"
        self.name = name
        self.addonID = addonID
        self.catalogType = catalogType
        self.catalogID = catalogID
    }

    var isAddon: Bool { addonID != nil }
}

/// Bewaart de eigen lijst streamingdiensten. Geen lijst opgeslagen = de standaarddiensten van je regio.
nonisolated enum VeyraStreamingStore {
    private static let key = "veyra.bento.streaming"

    static func load() -> [BentoStreamingEntry]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([BentoStreamingEntry].self, from: data)
    }

    static func save(_ entries: [BentoStreamingEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Eigen logo (URL of lokale foto); nil = standaardlogo.
    static func logoURL(for entry: BentoStreamingEntry) -> URL? {
        guard let custom = entry.customLogo, !custom.isEmpty else { return nil }
        if custom.hasPrefix("http") { return URL(string: custom) }
        let local = VeyraCollectionsStore.imagesDirectory.appendingPathComponent(custom)
        return FileManager.default.fileExists(atPath: local.path) ? local : nil
    }
}

// MARK: - Netwerk

private actor VeyraCatalogCache {
    static let shared = VeyraCatalogCache()
    private var providerEntries: [String: [BentoStreamingEntry]] = [:]
    private var wideLogos: [Int: String] = [:]      // "" = geen woordmerk gevonden
    private var defaults: [BentoCollectionEntry] = []

    func cachedProviderEntries(region: String) -> [BentoStreamingEntry] { providerEntries[region] ?? [] }
    func setProviderEntries(_ value: [BentoStreamingEntry], region: String) { providerEntries[region] = value }
    func cachedWide(_ providerID: Int) -> String? { wideLogos[providerID] }
    func setWide(_ providerID: Int, url: URL?) { wideLogos[providerID] = url?.absoluteString ?? "" }
    func cachedDefaults() -> [BentoCollectionEntry] { defaults }
    func setDefaults(_ value: [BentoCollectionEntry]) { defaults = value }
}

private nonisolated enum VeyraTMDBHTTP {
    static func get<T: Decodable>(_ path: String, _ query: [URLQueryItem] = [], as type: T.Type) async -> T? {
        let token: String? = await MainActor.run { AppConfiguration.tmdbReadAccessToken }
        guard let token, !token.isEmpty,
              var components = URLComponents(string: VeyraEndpoints.tmdb + path) else { return nil }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

/// Dezelfde dertien streamingdiensten als in Films/Series, en een vaste lijst bekende filmreeksen (via TMDB-zoekopdracht).
nonisolated struct VeyraCatalogSource: Sendable {
    private nonisolated struct ProviderPage: Decodable {
        nonisolated struct Item: Decodable {
            let provider_id: Int
            let provider_name: String
            let logo_path: String?
            let display_priority: Int?
        }
        let results: [Item]
    }

    private nonisolated struct CollectionSearch: Decodable {
        nonisolated struct Item: Decodable {
            let id: Int
            let name: String
            let poster_path: String?
            let backdrop_path: String?
        }
        let results: [Item]
    }

    private nonisolated struct CompanySearch: Decodable {
        nonisolated struct Item: Decodable {
            let name: String
            let logo_path: String?
        }
        let results: [Item]
    }

    private nonisolated struct NetworkDetail: Decodable {
        let name: String
        let logo_path: String?
    }

    private nonisolated struct CollectionDetail: Decodable {
        nonisolated struct Part: Decodable {
            let id: Int
            let title: String?
            let poster_path: String?
            let backdrop_path: String?
            let release_date: String?
        }
        let parts: [Part]
    }

    private nonisolated struct TitlePage: Decodable {
        nonisolated struct Item: Decodable {
            let id: Int
            let title: String?
            let name: String?
            let poster_path: String?
            let backdrop_path: String?
        }
        let results: [Item]
    }

    /// Zelfde merken en volgorde als `TMDBClient.watchProviders`.
    private static let brands: [[Int]] = [
        [8], [9, 119], [337, 122], [1899], [350], [531], [15],
        [386, 387], [99], [524, 510, 520], [43], [34], [526]
    ]

    /// Streamingdienst (TMDB provider-id) -> TMDB-netwerk met het brede woordmerk, en een merkkleur.
    /// De naam van het netwerk wordt gecontroleerd, zodat een verkeerd id nooit een verkeerd logo geeft.
    private static let networks: [Int: (id: Int, key: String, brand: UInt32)] = [
        8: (213, "netflix", 0xB20710),
        9: (1024, "prime", 0x0A5FA8), 119: (1024, "prime", 0x0A5FA8),
        337: (2739, "disney", 0x113CCF), 122: (2739, "disney", 0x113CCF),
        1899: (3186, "hbo", 0x5B2A96),
        350: (2552, "apple", 0x3A3A3C),
        531: (4330, "paramount", 0x0B4FD1),
        15: (453, "hulu", 0x0E8A5A),
        386: (3353, "peacock", 0x2B2B2B), 387: (3353, "peacock", 0x2B2B2B),
        43: (318, "starz", 0x333333)
    ]

    private static let franchises: [String] = [
        "Star Wars", "Harry Potter", "James Bond", "The Lord of the Rings", "The Hobbit",
        "Fast & Furious", "Mission: Impossible", "Jurassic Park", "Indiana Jones", "Toy Story",
        "Pirates of the Caribbean", "The Dark Knight", "The Avengers", "Iron Man", "John Wick",
        "The Matrix", "Alien", "Terminator", "The Hunger Games", "Shrek",
        "Back to the Future", "Die Hard", "Planet of the Apes", "Spider-Man"
    ]

    private static var region: String {
        UserDefaults.standard.string(forKey: "catalog.watchRegion") ?? "BE"
    }

    private static func imageURL(_ path: String?, size: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }

    // MARK: Streamingdiensten

    /// Alle aanbieders in je regio (zonder winkels), op populariteit; voor de standaardlijst en de kiezer in Instellingen.
    func regionalProviders() async -> [BentoStreamingEntry] {
        let region = Self.region
        let cached = await VeyraCatalogCache.shared.cachedProviderEntries(region: region)
        if !cached.isEmpty { return cached }
        guard let page = await VeyraTMDBHTTP.get("/watch/providers/movie",
                                                 [.init(name: "watch_region", value: region)],
                                                 as: ProviderPage.self) else { return [] }
        let entries = page.results
            .sorted { ($0.display_priority ?? 999) < ($1.display_priority ?? 999) }
            .map { BentoStreamingEntry(providerID: $0.provider_id, name: $0.provider_name, logoPath: $0.logo_path) }
        if !entries.isEmpty { await VeyraCatalogCache.shared.setProviderEntries(entries, region: region) }
        return entries
    }

    /// Standaardlijst: de vaste merken in vaste volgorde, daarna de overige abonnementsdiensten in je regio.
    func defaultStreamingEntries() async -> [BentoStreamingEntry] {
        let all = await regionalProviders()
        var list: [BentoStreamingEntry] = []
        var used = Set<Int>()
        for ids in Self.brands {
            for id in ids {
                if let entry = all.first(where: { $0.providerID == id }) {
                    if used.insert(id).inserted { list.append(entry) }
                    break
                }
            }
        }
        for entry in all where list.count < Self.maxProviders && !Self.isExcluded(entry.name) {
            if let id = entry.providerID, used.insert(id).inserted { list.append(entry) }
        }
        return list
    }

    /// Aanbieders die je nog kunt toevoegen (winkels vallen af).
    func selectableProviders() async -> [BentoStreamingEntry] {
        await regionalProviders().filter { !Self.isExcluded($0.name) }
    }

    /// De eigen lijst van de gebruiker, of anders de standaarddiensten; met breed woordmerk waar dat bekend is.
    func providers() async -> [BentoCatalog] {
        let entries: [BentoStreamingEntry]
        if let custom = VeyraStreamingStore.load() {
            entries = custom
        } else {
            entries = await defaultStreamingEntries()
        }
        var result = entries.map { catalog(for: $0) }

        await withTaskGroup(of: (Int, URL?).self) { group in
            for (index, entry) in entries.enumerated() {
                guard let providerID = entry.providerID, result[index].customLogoURL == nil else { continue }
                let name = entry.name
                group.addTask {
                    if let cached = await VeyraCatalogCache.shared.cachedWide(providerID) {
                        return (index, cached.isEmpty ? nil : URL(string: cached))
                    }
                    var url: URL?
                    if let network = Self.networks[providerID] {
                        url = await self.wideLogo(networkID: network.id, key: network.key)
                    }
                    if url == nil { url = await self.companyLogo(name: name) }
                    await VeyraCatalogCache.shared.setWide(providerID, url: url)
                    return (index, url)
                }
            }
            for await (index, url) in group { result[index].wideURL = url }
        }
        return result
    }

    private func catalog(for entry: BentoStreamingEntry) -> BentoCatalog {
        let custom = VeyraStreamingStore.logoURL(for: entry)
        if let addonID = entry.addonID, let type = entry.catalogType, let catalogID = entry.catalogID {
            return BentoCatalog(source: .addonCatalog(addonID, type, catalogID), name: entry.name,
                                imageURL: custom, customLogoURL: custom)
        }
        let providerID = entry.providerID ?? 0
        return BentoCatalog(source: .provider(providerID), name: entry.name,
                            imageURL: Self.imageURL(entry.logoPath, size: "w154"),
                            brand: Self.networks[providerID]?.brand, customLogoURL: custom)
    }

    private static let maxProviders = 36

    /// Winkels (kopen/huren) en dubbele varianten vallen af.
    private static func isExcluded(_ name: String) -> Bool {
        let lower = name.lowercased()
        return ["amazon video", "google play", "itunes", "youtube", "channel", "with ads", "microsoft store", "rakuten"]
            .contains { lower.contains($0) }
    }

    private static func normalized(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    private func companyLogo(name: String) async -> URL? {
        guard let page = await VeyraTMDBHTTP.get("/search/company", [.init(name: "query", value: name)], as: CompanySearch.self) else { return nil }
        let target = Self.normalized(name)
        guard let hit = page.results.first(where: { Self.normalized($0.name) == target && $0.logo_path != nil }) else { return nil }
        return Self.imageURL(hit.logo_path, size: "w300")
    }

    private func wideLogo(networkID: Int, key: String) async -> URL? {
        guard let detail = await VeyraTMDBHTTP.get("/network/\(networkID)", as: NetworkDetail.self),
              detail.name.lowercased().contains(key) else { return nil }
        return Self.imageURL(detail.logo_path, size: "w300")
    }

    // MARK: Filmcollecties

    /// De eigen lijst van de gebruiker, of anders de standaard franchises.
    func collections() async -> [BentoCatalog] {
        let entries: [BentoCollectionEntry]
        if let custom = VeyraCollectionsStore.load() {
            entries = custom
        } else {
            entries = await defaultEntries()
        }
        return entries.map { $0.catalog }
    }

    /// De standaard franchises, opgezocht via TMDB (eenmalig per sessie).
    func defaultEntries() async -> [BentoCollectionEntry] {
        let cached = await VeyraCatalogCache.shared.cachedDefaults()
        if !cached.isEmpty { return cached }

        let found = await withTaskGroup(of: (Int, BentoCollectionEntry?).self) { group -> [BentoCollectionEntry] in
            for (index, franchise) in Self.franchises.enumerated() {
                group.addTask {
                    let hits = await self.searchCollections(franchise + " Collection")
                    return (index, hits.first)
                }
            }
            var pairs: [(Int, BentoCollectionEntry)] = []
            for await (index, value) in group {
                if let value { pairs.append((index, value)) }
            }
            return pairs.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        var seen = Set<String>()
        let unique = found.filter { seen.insert($0.id).inserted }
        if !unique.isEmpty { await VeyraCatalogCache.shared.setDefaults(unique) }
        return unique
    }

    /// Zoekt TMDB-collecties op naam; alleen resultaten met een afbeelding.
    func searchCollections(_ query: String) async -> [BentoCollectionEntry] {
        let items: [URLQueryItem] = [.init(name: "query", value: query), .init(name: "language", value: "nl-BE")]
        guard let page = await VeyraTMDBHTTP.get("/search/collection", items, as: CollectionSearch.self) else { return [] }
        return page.results.compactMap { hit in
            guard let path = hit.backdrop_path ?? hit.poster_path else { return nil }
            return BentoCollectionEntry(tmdbID: hit.id, name: Self.cleanName(hit.name), imagePath: path)
        }
    }

    private static func cleanName(_ raw: String) -> String {
        var text = raw
        for suffix in [" - Filmreeks", " Filmreeks", " (Filmreeks)", " - Collectie", " Collectie", " (Collectie)",
                       " - Collection", " Collection", " (Collection)"] where text.hasSuffix(suffix) {
            text = String(text.dropLast(suffix.count))
        }
        return text.trimmingCharacters(in: .whitespaces)
    }

    // MARK: Overzichtsscherm

    func sections(for catalog: BentoCatalog) async -> [BentoCatalogSection] {
        switch catalog.source {
        case .provider(let id):
            async let films = discover(kind: .movie, provider: id)
            async let series = discover(kind: .episode, provider: id)
            let (movieTitles, seriesTitles) = await (films, series)
            var result: [BentoCatalogSection] = []
            if !movieTitles.isEmpty { result.append(BentoCatalogSection(id: "films", heading: "Films", titles: movieTitles)) }
            if !seriesTitles.isEmpty { result.append(BentoCatalogSection(id: "series", heading: "Series", titles: seriesTitles)) }
            return result
        case .collection(let id):
            let titles = await collectionParts(id)
            return titles.isEmpty ? [] : [BentoCatalogSection(id: "films", heading: "Films", titles: titles)]
        case .traktList(let id):
            async let films = VeyraTraktListSource.titles(listID: id, kind: .movie)
            async let series = VeyraTraktListSource.titles(listID: id, kind: .series)
            let (movieTitles, seriesTitles) = await (films, series)
            var result: [BentoCatalogSection] = []
            if !movieTitles.isEmpty { result.append(BentoCatalogSection(id: "films", heading: "Films", titles: movieTitles)) }
            if !seriesTitles.isEmpty { result.append(BentoCatalogSection(id: "series", heading: "Series", titles: seriesTitles)) }
            return result
        case .addonCatalog(let addonID, let type, let catalogID):
            let titles = await VeyraAddonCatalogSource.titles(addonID: addonID, type: type, catalogID: catalogID)
            guard !titles.isEmpty else { return [] }
            return [BentoCatalogSection(id: type, heading: type == "series" ? "Series" : "Films", titles: titles)]
        }
    }

    /// Altijd nieuwste eerst (releasedatum / eerste uitzending, niet in de toekomst).
    private func discover(kind: MediaKind, provider: Int) async -> [BentoTMDBTitle] {
        let isMovie = kind == .movie
        let path = isMovie ? "/discover/movie" : "/discover/tv"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        var all: [BentoTMDBTitle] = []
        for page in 1...3 {
            let query: [URLQueryItem] = [
                .init(name: "with_watch_providers", value: String(provider)),
                .init(name: "watch_region", value: Self.region),
                .init(name: "with_watch_monetization_types", value: "flatrate"),
                .init(name: "sort_by", value: isMovie ? "primary_release_date.desc" : "first_air_date.desc"),
                .init(name: isMovie ? "primary_release_date.lte" : "first_air_date.lte", value: today),
                .init(name: "language", value: "nl-BE"),
                .init(name: "include_adult", value: "false"),
                .init(name: "page", value: String(page))
            ]
            guard let result = await VeyraTMDBHTTP.get(path, query, as: TitlePage.self) else { break }
            for item in result.results {
                guard let title = item.title ?? item.name, item.poster_path != nil else { continue }
                all.append(BentoTMDBTitle(id: item.id, kind: kind, title: title,
                                          posterURL: Self.imageURL(item.poster_path, size: "w342"),
                                          backdropURL: Self.imageURL(item.backdrop_path, size: "w1280")))
            }
            if result.results.count < 20 { break }
        }
        return all
    }

    private nonisolated struct CollectionImages: Decodable {
        nonisolated struct Image: Decodable { let file_path: String }
        let backdrops: [Image]
    }

    /// Mogelijke banners uit de bronnen: TMDB-collectiebeelden, backdrops en (met fanart-sleutel) banners van de titels.
    func bannerOptions(for entry: BentoCollectionEntry) async -> [URL] {
        var urls: [URL] = []
        var titles: [BentoTMDBTitle] = []

        if let listID = entry.traktListID {
            let films = await VeyraTraktListSource.titles(listID: listID, kind: .movie)
            let series = await VeyraTraktListSource.titles(listID: listID, kind: .series)
            titles = films + series
        } else if let tmdbID = entry.tmdbID {
            let query: [URLQueryItem] = [.init(name: "include_image_language", value: "null,nl,en")]
            if let images = await VeyraTMDBHTTP.get("/collection/\(tmdbID)/images", query, as: CollectionImages.self) {
                for image in images.backdrops.prefix(10) {
                    if let url = Self.imageURL(image.file_path, size: "w780") { urls.append(url) }
                }
            }
            titles = await collectionParts(tmdbID)
        }

        let artwork = VeyraTMDBArtwork()
        let extra = await withTaskGroup(of: [URL].self) { group -> [URL] in
            for title in titles.prefix(8) {
                group.addTask {
                    let found = await artwork.artwork(for: title.kind, tmdbID: title.id)
                    return [found?.banner, found?.backdrop].compactMap { $0 }
                }
            }
            var all: [URL] = []
            for await part in group { all += part }
            return all
        }
        urls += extra

        var seen = Set<URL>()
        return urls.filter { seen.insert($0).inserted }
    }

    private func collectionParts(_ id: Int) async -> [BentoTMDBTitle] {
        guard let detail = await VeyraTMDBHTTP.get("/collection/\(id)",
                                                   [.init(name: "language", value: "nl-BE")],
                                                   as: CollectionDetail.self) else { return [] }
        let ordered = detail.parts.sorted { ($0.release_date ?? "9999") < ($1.release_date ?? "9999") }
        var titles: [BentoTMDBTitle] = []
        for part in ordered {
            guard let title = part.title else { continue }
            titles.append(BentoTMDBTitle(id: part.id, kind: .movie, title: title,
                                         posterURL: Self.imageURL(part.poster_path, size: "w342"),
                                         backdropURL: Self.imageURL(part.backdrop_path, size: "w1280")))
        }
        return titles
    }
}

// MARK: - Overzichtsscherm

/// Films en series van één streamingdienst (nieuwste eerst, met knoppen), of alle delen van één filmcollectie.
struct VeyraBentoCatalogView: View {
    let catalog: BentoCatalog
    var onOpen: (BentoTMDBTitle) -> Void = { _ in }

    @State private var sections: [BentoCatalogSection] = []
    @State private var selected = ""
    @State private var heroURL: URL?
    @State private var loading = true

    #if os(tvOS)
    private let compact = false
    #else
    private let compact = true
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var gridColumns: [GridItem] {
        #if os(tvOS)
        return [GridItem(.adaptive(minimum: 246, maximum: 256), spacing: 28, alignment: .top)]
        #else
        if sizeClass == .regular {
            return [GridItem(.adaptive(minimum: 170, maximum: 210), spacing: 16, alignment: .top)]
        }
        return [GridItem(.flexible(), spacing: 14, alignment: .top), GridItem(.flexible(), spacing: 14, alignment: .top)]
        #endif
    }

    private var current: BentoCatalogSection? {
        sections.first { $0.id == selected } ?? sections.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 16 : 30) {
                hero

                if sections.count > 1 {
                    HStack(spacing: compact ? 10 : 20) {
                        ForEach(sections) { section in tab(section) }
                    }
                }

                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if current == nil {
                    Text("Niets gevonden.")
                        .font(.title3)
                        .foregroundStyle(VeyraHomeStyle.dim)
                }

                if let current {
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: compact ? 18 : 34) {
                        ForEach(current.titles) { title in card(title) }
                    }
                }
            }
            .padding(compact ? 16 : 60)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(VeyraHomeStyle.ink.ignoresSafeArea())
        .foregroundStyle(.white)
        #if !os(tvOS)
        .navigationTitle(catalog.name)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: catalog.id) {
            loading = true
            let loaded = await VeyraCatalogSource().sections(for: catalog)
            sections = loaded
            selected = loaded.first?.id ?? ""
            heroURL = Self.heroImage(catalog: catalog, sections: loaded)
            loading = false
        }
    }

    // MARK: Grote afbeelding

    private static func heroImage(catalog: BentoCatalog, sections: [BentoCatalogSection]) -> URL? {
        if catalog.isService {
            // Dienst: een willekeurige backdrop uit het aanbod.
        } else if let url = catalog.imageURL {
            return URL(string: url.absoluteString.replacingOccurrences(of: "/w780/", with: "/w1280/")) ?? url
        }
        let candidates = sections.flatMap { $0.titles }.compactMap { $0.backdropURL }
        return candidates.prefix(12).randomElement()
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Color.white.opacity(0.05)
            if let heroURL {
                AsyncImage(url: heroURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                }
            }
            LinearGradient(colors: [.clear, VeyraHomeStyle.ink.opacity(0.92)], startPoint: UnitPoint(x: 0.5, y: 0.25), endPoint: .bottom)
            LinearGradient(colors: [VeyraHomeStyle.ink.opacity(0.7), .clear], startPoint: .leading, endPoint: UnitPoint(x: 0.7, y: 0.5))
            heroTitle
                .padding(compact ? 16 : 40)
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 220 : 460)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 20 : 32, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(catalog.name)
    }

    @ViewBuilder
    private var heroTitle: some View {
        if let custom = catalog.customLogoURL {
            AsyncImage(url: custom) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit()
                case .failure: nameText
                default: Color.clear
                }
            }
            .frame(width: compact ? 200 : 460, height: compact ? 56 : 130, alignment: .leading)
            .shadow(color: .black.opacity(0.5), radius: 10)
        } else if let wide = catalog.wideURL {
            AsyncImage(url: wide) { phase in
                switch phase {
                case .success(let image):
                    image.renderingMode(.template).resizable().scaledToFit().foregroundStyle(.white)
                case .failure:
                    iconAndName
                default:
                    Color.clear
                }
            }
            .frame(width: compact ? 200 : 460, height: compact ? 56 : 130, alignment: .leading)
            .shadow(color: .black.opacity(0.5), radius: 10)
        } else {
            iconAndName
        }
    }

    @ViewBuilder
    private var iconAndName: some View {
        if let icon = catalog.imageURL, catalog.isService {
            HStack(spacing: compact ? 12 : 22) {
                AsyncImage(url: icon) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Color.white.opacity(0.1) }
                }
                .frame(width: compact ? 48 : 100, height: compact ? 48 : 100)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 11 : 22, style: .continuous))
                nameText
            }
        } else {
            nameText
        }
    }

    private var nameText: some View {
        Text(catalog.name)
            .font(.system(size: compact ? 28 : 64, weight: .bold))
            .lineLimit(2)
            .minimumScaleFactor(0.6)
    }

    // MARK: Knoppen en kaarten

    @ViewBuilder
    private func tab(_ section: BentoCatalogSection) -> some View {
        if section.id == (current?.id ?? "") {
            Button { selected = section.id } label: {
                Text(section.heading)
                    .font(.system(size: compact ? 16 : 28, weight: .semibold))
                    .padding(.horizontal, compact ? 8 : 24)
                    .padding(.vertical, compact ? 2 : 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(VeyraColors.cyan)
        } else {
            Button { selected = section.id } label: {
                Text(section.heading)
                    .font(.system(size: compact ? 16 : 28, weight: .semibold))
                    .padding(.horizontal, compact ? 8 : 24)
                    .padding(.vertical, compact ? 2 : 8)
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
    }

    @ViewBuilder
    private func card(_ title: BentoTMDBTitle) -> some View {
        #if os(tvOS)
        Button { onOpen(title) } label: {
            VeyraBentoPosterContent(title: title.title, url: title.posterURL, kind: title.kind, posterHeight: 360, titleSize: 24, watchedID: title.id, watchedKind: title.kind)
        }
        .buttonStyle(VeyraPosterFocusStyle())
        #else
        Button { onOpen(title) } label: {
            VeyraBentoPosterContent(title: title.title, url: title.posterURL, compact: true, kind: title.kind, titleSize: 15, fillWidth: true, watchedID: title.id, watchedKind: title.kind)
        }
        .buttonStyle(.plain)
        #endif
    }
}

// MARK: - Instellingen: filmcollecties

/// Collecties op Home: volgorde, banner, toevoegen (zoeken of eigen Trakt-lijst), verwijderen, standaardlijst herstellen.
struct VeyraCollectionsSettingsView: View {
    @State private var entries: [BentoCollectionEntry] = []
    @State private var loading = true
    @State private var query = ""
    @State private var results: [BentoCollectionEntry] = []
    @State private var searching = false
    @State private var searched = false
    @State private var traktLists: [TraktPersonalList] = []
    @State private var loadingTrakt = false
    @State private var traktLoaded = false

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Form {
            Section {
                if loading {
                    ProgressView()
                } else if entries.isEmpty {
                    Text("Nog geen collecties.").foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    NavigationLink {
                        VeyraCollectionEditorView(entryID: entry.id, entries: $entries)
                    } label: {
                        row(entry)
                    }
                }
            } header: {
                Text("Collecties op Home")
            } footer: {
                Text("Kies een collectie om de volgorde, naam of banner aan te passen, of om hem te verwijderen.")
            }

            Section {
                TextField("Zoek een filmcollectie, bv. Alien", text: $query)
                    .onSubmit { Task { await search() } }
                Button("Zoeken") { Task { await search() } }
                    .disabled(trimmed.isEmpty || searching)
                if searching {
                    ProgressView()
                } else if searched && results.isEmpty {
                    Text("Niets gevonden.").foregroundStyle(.secondary)
                }
                ForEach(results) { result in
                    Button { add(result) } label: {
                        HStack {
                            Text(result.name)
                            Spacer()
                            Image(systemName: "plus.circle").foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Filmcollectie toevoegen")
            }

            Section {
                Button(loadingTrakt ? "Laden…" : "Mijn Trakt-lijsten tonen") { Task { await loadTraktLists() } }
                    .disabled(loadingTrakt)
                if traktLoaded && availableTraktLists.isEmpty {
                    Text("Geen (nieuwe) lijsten gevonden. Is Trakt gekoppeld?").foregroundStyle(.secondary)
                }
                ForEach(availableTraktLists, id: \.ids.trakt) { list in
                    Button { addTrakt(list) } label: {
                        HStack {
                            Text(list.name)
                            Spacer()
                            Image(systemName: "plus.circle").foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Trakt-lijst toevoegen")
            } footer: {
                Text("Een eigen Trakt-lijst verschijnt als collectie, met de films en series uit die lijst.")
            }

            Section {
                Button("Standaardlijst herstellen") { reset() }
            }
        }
        .navigationTitle("Filmcollecties")
        .task { await load() }
    }

    private var availableTraktLists: [TraktPersonalList] {
        traktLists.filter { list in !entries.contains(where: { $0.traktListID == list.ids.trakt }) }
    }

    private func row(_ entry: BentoCollectionEntry) -> some View {
        HStack(spacing: 14) {
            AsyncImage(url: VeyraCollectionsStore.imageURL(for: entry)) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { Color.white.opacity(0.08) }
            }
            .frame(width: 96, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                Text(entry.isTraktList ? "Trakt-lijst" : "TMDB-collectie")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() async {
        loading = true
        if let custom = VeyraCollectionsStore.load() {
            entries = custom
        } else {
            entries = await VeyraCatalogSource().defaultEntries()
        }
        loading = false
    }

    private func persist() { VeyraCollectionsStore.save(entries) }

    private func add(_ entry: BentoCollectionEntry) {
        if !entries.contains(where: { $0.id == entry.id }) { entries.append(entry) }
        persist()
        results.removeAll { $0.id == entry.id }
    }

    private func addTrakt(_ list: TraktPersonalList) {
        let entry = BentoCollectionEntry(traktListID: list.ids.trakt, slug: list.ids.slug, name: list.name)
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        persist()
        // Standaardbanner: de eerste afbeelding uit de bronnen.
        Task {
            guard let first = await VeyraCatalogSource().bannerOptions(for: entry).first,
                  let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
            entries[index].imagePath = first.absoluteString
            persist()
        }
    }

    private func loadTraktLists() async {
        loadingTrakt = true
        traktLists = await VeyraTraktListSource.personalLists()
        traktLoaded = true
        loadingTrakt = false
    }

    private func reset() {
        VeyraCollectionsStore.reset()
        Task { await load() }
    }

    private func search() async {
        guard !trimmed.isEmpty else { return }
        searching = true
        let found = await VeyraCatalogSource().searchCollections(trimmed)
        results = found.filter { hit in !entries.contains(where: { $0.id == hit.id }) }
        searched = true
        searching = false
    }
}

/// Eén collectie aanpassen: naam, volgorde, banner (uit bronnen, eigen URL of eigen foto) en verwijderen.
struct VeyraCollectionEditorView: View {
    let entryID: String
    @Binding var entries: [BentoCollectionEntry]

    @Environment(\.dismiss) private var dismiss
    @State private var options: [URL] = []
    @State private var loadingOptions = false
    @State private var optionsLoaded = false
    @State private var urlText = ""
    #if os(iOS)
    @State private var photo: PhotosPickerItem?
    #endif

    private var index: Int? { entries.firstIndex { $0.id == entryID } }

    var body: some View {
        Form {
            if let index {
                Section {
                    TextField("Naam", text: nameBinding(index))
                } header: {
                    Text("Naam")
                }

                Section {
                    Button("Naar boven") { move(index, by: -1) }.disabled(index == 0)
                    Button("Naar beneden") { move(index, by: 1) }.disabled(index >= entries.count - 1)
                } header: {
                    Text("Volgorde (positie \(index + 1) van \(entries.count))")
                }

                Section {
                    AsyncImage(url: VeyraCollectionsStore.imageURL(for: entries[index])) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Color.white.opacity(0.08) }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button(loadingOptions ? "Laden…" : "Kies uit bronnen (TMDB, fanart)") { Task { await loadOptions() } }
                        .disabled(loadingOptions)
                    if optionsLoaded && options.isEmpty {
                        Text("Geen afbeeldingen gevonden.").foregroundStyle(.secondary)
                    }
                    if !options.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(options, id: \.self) { url in
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image { image.resizable().scaledToFill() } else { Color.white.opacity(0.08) }
                                    }
                                    .frame(width: 240, height: 135)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .contentShape(Rectangle())
                                    // Een `Button` in een horizontale ScrollView binnenin een Form-rij
                                    // krijgt op iOS soms geen tikken (de rij "wint" de gesture) — een
                                    // losse tap-gesture op de afbeelding zelf werkt wel betrouwbaar.
                                    .onTapGesture { setImage(url.absoluteString) }
                                }
                            }
                            .padding(8)
                        }
                        .scrollClipDisabled()
                    }

                    TextField("Eigen afbeelding (https-adres)", text: $urlText)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                    Button("Dit adres gebruiken") { useURLText() }
                        .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)

                    #if os(iOS)
                    PhotosPicker("Kies een foto uit Foto's", selection: $photo, matching: .images)
                    #endif

                    Button("Standaardbanner herstellen") { setImage(nil) }
                } header: {
                    Text("Banner")
                }

                Section {
                    Button("Verwijderen", role: .destructive) { remove(index) }
                }
            }
        }
        .navigationTitle("Collectie")
        #if os(iOS)
        .onChange(of: photo) { _, item in
            Task { await importPhoto(item) }
        }
        #endif
    }

    private func nameBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { entries.indices.contains(index) ? entries[index].name : "" },
            set: { newValue in
                guard entries.indices.contains(index) else { return }
                entries[index].name = newValue
                VeyraCollectionsStore.save(entries)
            })
    }

    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard entries.indices.contains(target) else { return }
        entries.swapAt(index, target)
        VeyraCollectionsStore.save(entries)
    }

    private func setImage(_ value: String?) {
        guard let index else { return }
        entries[index].customImage = value
        VeyraCollectionsStore.save(entries)
    }

    private func useURLText() {
        let text = urlText.trimmingCharacters(in: .whitespaces)
        guard text.lowercased().hasPrefix("http") else { return }
        setImage(text)
        urlText = ""
    }

    private func remove(_ index: Int) {
        guard entries.indices.contains(index) else { return }
        entries.remove(at: index)
        VeyraCollectionsStore.save(entries)
        dismiss()
    }

    private func loadOptions() async {
        guard let index else { return }
        loadingOptions = true
        options = await VeyraCatalogSource().bannerOptions(for: entries[index])
        optionsLoaded = true
        loadingOptions = false
    }

    #if os(iOS)
    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.85),
              let name = VeyraCollectionsStore.saveImage(jpeg) else { return }
        setImage(name)
        photo = nil
    }
    #endif
}
