import Foundation

/// Centrale metadata-ophaling (spec "METADATA + AIOMETADATA + ARTWORK
/// ENGINE" Fase 1, §14/§16/§18/§19/§21/§22/§23/§24): één gedeelde ingang die
/// `MetadataSourcePolicy` raadpleegt en vervolgens TMDB of AIOMetadata
/// bevraagt, normaliseert naar het bestaande canonical `MediaItem`-model en
/// cachet het resultaat source-aware — zodat `ShelfCatalogService` en latere
/// aanroepers niet meer elk hun eigen bron-/cache-logica dupliceren.
///
/// Dit vervangt vooralsnog alleen de artwork-verrijking die al door
/// `ShelfCatalogService.enrich` gebeurde (de enige bestaande consument van
/// `MetadataSourcePreference`, zie Fase 0-audit); het aansluiten van de
/// overige ~35 rechtstreekse-TMDB-aanroepen (Movies/Series/Search/Home/
/// Player) is bewust nog niet in deze stap meegenomen.
actor MetadataRepository {
    static let shared = MetadataRepository()

    /// Reparatie (A/B-testrapport §17/§35): leest zowel via IMDb-ID als via de
    /// live-geverifieerde `tmdb:{id}`-prefix die de addon ook accepteert —
    /// voorheen leverde een titel zonder IMDb-ID (bv. Château Planckaert) hier
    /// altijd `nil` op, terwijl de addon zelf wel op TMDB-ID kan zoeken.
    private enum AIOLookupID: Hashable {
        case imdb(String)
        case tmdb(Int)

        var cacheKey: String {
            switch self {
            case .imdb(let id): return id
            case .tmdb(let id): return "tmdb:\(id)"
            }
        }
    }

    private struct AIOCacheKey: Hashable {
        let addonID: UUID
        let lookupKey: String
        let kind: ShelfMediaKind
    }

    // Cache-first (§22) + source-aware (§23): een addon-wissel mag nooit een
    // oude AIOMetadata-respons van een ANDERE addon tonen, dus het addon-ID
    // zit in de key. Een wissel van AIOMetadata → TMDB raakt deze cache niet
    // — dat pad loopt via de al bestaande `TMDBMetadataCache`, die apart
    // blijft (gebruikt ook door Collections, zie Fase 0-audit).
    private var aioCache = VeyraBoundedCache<AIOCacheKey, AIOMetaItem>(countLimit: 512)
    private var cacheGeneration: UInt64 = 0
    var cachedCount: Int { aioCache.count }
    func clearCache() {
        cacheGeneration &+= 1
        aioCache.removeAll()
        for task in inFlight.values { task.cancel() }
        inFlight.removeAll()
    }

    // Request-deduplicatie (§24): als meerdere cards tegelijk om dezelfde
    // AIOMetadata-meta vragen, wacht de tweede op de al lopende aanvraag in
    // plaats van er zelf nog een te starten.
    private var inFlight: [AIOCacheKey: Task<AIOMetaItem?, Never>] = [:]

    /// Verrijkt `item` met poster/backdrop/overview via de huidige
    /// metadatabron, met TMDB als terugval (§19) als AIOMetadata faalt of er
    /// geen bruikbare ID voorhanden is. Wijzigt nooit `item.tmdbID`/
    /// `item.imdbID` zelf — alleen de presentatievelden.
    func enrichedArtwork(for item: MediaItem, kind: ShelfMediaKind) async -> MediaItem {
        let resolved = await resolveArtwork(for: item, kind: kind)

        // §58 prioriteit 1: een handmatig gekozen poster/backdrop voor DEZE titel staat boven
        // de automatische resolver -- maar de automatische resolutie loopt hierboven altijd nog
        // wel door, zodat overview/genre/rating/imdbID gewoon gevuld blijven (de override raakt
        // alleen de twee afbeeldingsvelden, niet de rest van de metadata).
        guard let tmdbID = item.tmdbID else { return resolved }
        let canonicalKey = VeyraArtworkOverrideStore.canonicalKey(tmdbID: tmdbID, kind: kind)
        let overrideStore = VeyraArtworkOverrideStore()
        let posterOverride = overrideStore.resolvedURL(canonicalKey: canonicalKey, type: .poster)
        let backdropOverride = overrideStore.resolvedURL(canonicalKey: canonicalKey, type: .backdrop)
        guard posterOverride != nil || backdropOverride != nil else { return resolved }

        await MetadataDiagnosticsRecorder.log(
            kind: .artwork, canonicalID: "tmdb:\(tmdbID)", sourceSelected: "override", sourceActuallyUsed: "override",
            fallbackUsed: false, cacheHit: false,
            candidateID: [posterOverride?.lastPathComponent, backdropOverride?.lastPathComponent]
                .compactMap { $0 }.joined(separator: ","),
            since: Date()
        )

        return MediaItem(
            id: resolved.id,
            title: resolved.title,
            type: resolved.type,
            imdbID: resolved.imdbID,
            tmdbID: resolved.tmdbID,
            overview: resolved.overview,
            releaseDate: resolved.releaseDate,
            posterURL: posterOverride ?? resolved.posterURL,
            backdropURL: backdropOverride ?? resolved.backdropURL,
            genre: resolved.genre,
            rating: resolved.rating,
            catalogItemID: resolved.catalogItemID
        )
    }

    private func resolveArtwork(for item: MediaItem, kind: ShelfMediaKind) async -> MediaItem {
        let start = Date()
        let canonicalID = item.tmdbID.map { "tmdb:\($0)" } ?? (item.imdbID ?? "?")

        switch MetadataSourcePolicy.activeSource() {
        case .aioMetadata(let addon):
            let cacheHit = aioCacheContains(addon: addon, imdbID: item.imdbID, tmdbID: item.tmdbID, kind: kind)
            let addonLabel = "\(addon.name) (\(addon.id.uuidString.prefix(8)))"
            if let meta = await resolvedAIOMeta(addon: addon, imdbID: item.imdbID, tmdbID: item.tmdbID, kind: kind) {
                await MetadataDiagnosticsRecorder.log(
                    kind: .metadata, canonicalID: canonicalID, sourceSelected: "aioMetadata",
                    sourceActuallyUsed: "aioMetadata", fallbackUsed: false, cacheHit: cacheHit,
                    addonID: addonLabel, since: start
                )
                return apply(meta, to: item)
            }
            // §19: addon offline/geen bruikbare ID/ongeldige respons → veilige
            // terugval op TMDB, zonder de opgeslagen voorkeur te wijzigen (§20).
            let result = await tmdbEnriched(item, kind: kind)
            await MetadataDiagnosticsRecorder.log(
                kind: .metadata, canonicalID: canonicalID, sourceSelected: "aioMetadata",
                sourceActuallyUsed: "tmdb", fallbackUsed: true, cacheHit: cacheHit,
                addonID: addonLabel, since: start
            )
            return result

        case .tmdb:
            let result = await tmdbEnriched(item, kind: kind)
            await MetadataDiagnosticsRecorder.log(
                kind: .metadata, canonicalID: canonicalID, sourceSelected: "tmdb",
                sourceActuallyUsed: "tmdb", fallbackUsed: false, cacheHit: false, since: start
            )
            return result
        }
    }

    /// §73 "Cache hit/miss": kijkt of de canonieke AIOMetadata-opzoeksleutel al in de cache zit,
    /// zonder zelf een aanvraag te starten.
    private func aioCacheContains(addon: AddonManifest, imdbID: String?, tmdbID: Int?, kind: ShelfMediaKind) -> Bool {
        guard let lookup = Self.canonicalLookup(imdbID: imdbID, tmdbID: tmdbID) else { return false }
        return aioCache.contains(AIOCacheKey(addonID: addon.id, lookupKey: lookup.cacheKey, kind: kind))
    }

    /// Bugfix (gevonden via Diagnostics, na de `imdbRating`-decodefix): verschillende
    /// aanroepers geven voor DEZELFDE titel niet altijd dezelfde velden mee -- `RibbonClearLogo`
    /// (Player-contextbalk) bouwt bv. een `MediaItem` met enkel `tmdbID`, terwijl Detail het volle
    /// item met `imdbID` doorgeeft. Met de oude "probeer eerst imdb, anders tmdb"-opzoeksleutel
    /// cachete dat als TWEE verschillende entries voor dezelfde titel -- zichtbaar in Diagnostics
    /// als 3 identieke, gelijktijdige, nooit-gecachete aanvragen voor hetzelfde tmdbID. tmdbID is
    /// de enige ID die ALLE aanroepers consistent meegeven (zelfde reden waarom
    /// `VeyraArtworkOverrideStore.canonicalKey` ook altijd op tmdbID werkt) -- dus die krijgt nu
    /// voorrang als cache-/dedup-sleutel, los van welke ID het eigenlijke netwerkverzoek gebruikt.
    private static func canonicalLookup(imdbID: String?, tmdbID: Int?) -> AIOLookupID? {
        if let tmdbID { return .tmdb(tmdbID) }
        if let imdbID, !imdbID.isEmpty { return .imdb(imdbID) }
        return nil
    }

    // MARK: - AIOMetadata

    private func resolvedAIOMeta(addon: AddonManifest, imdbID: String?, tmdbID: Int?, kind: ShelfMediaKind) async -> AIOMetaItem? {
        guard let cacheLookup = Self.canonicalLookup(imdbID: imdbID, tmdbID: tmdbID) else { return nil }
        let key = AIOCacheKey(addonID: addon.id, lookupKey: cacheLookup.cacheKey, kind: kind)

        if let cached = aioCache.value(for: key) {
            return cached
        }
        if let running = inFlight[key] {
            return await running.value
        }

        let generation = cacheGeneration
        let task = Task<AIOMetaItem?, Never> { [addon] in
            let client = AIOMetadataClient(baseURL: addon.baseURL)
            let type = kind == .movie ? "movie" : "series"
            // Het eigenlijke netwerkverzoek blijft wel eerst IMDb proberen (Fase 2-bevinding,
            // A/B-testrapport §17/§35), onafhankelijk van welke ID hierboven als cache-sleutel
            // diende.
            if let imdbID, !imdbID.isEmpty, let meta = try? await client.meta(type: type, imdbID: imdbID) {
                return meta
            }
            if let tmdbID, let meta = try? await client.meta(type: type, tmdbID: tmdbID) {
                return meta
            }
            return nil
        }
        inFlight[key] = task

        let result = await task.value
        guard generation == cacheGeneration else { return nil }
        inFlight[key] = nil
        if let result {
            aioCache.insert(result, for: key)
        }
        return result
    }

    /// Alleen het ClearLogo via de huidige AIOMetadata-addon (Fase 2-reparatie §27/§35: de
    /// addon levert dit al via `AIOMetaItem.logoURL`), voor gebruik door `ArtworkResolver`
    /// (Fase 3). Geeft `nil` als AIOMetadata niet de actieve bron is of geen logo teruggeeft —
    /// de aanroeper valt dan terug op TMDB.
    func aioLogoURL(for item: MediaItem, kind: ShelfMediaKind) async -> URL? {
        guard case .aioMetadata(let addon) = MetadataSourcePolicy.activeSource() else { return nil }
        guard let meta = await resolvedAIOMeta(addon: addon, imdbID: item.imdbID, tmdbID: item.tmdbID, kind: kind)
        else { return nil }
        return meta.logoURL
    }

    private func apply(_ meta: AIOMetaItem, to item: MediaItem) -> MediaItem {
        MediaItem(
            id: item.id,
            title: item.title,
            type: item.type,
            imdbID: item.imdbID,
            tmdbID: item.tmdbID,
            overview: item.overview?.isEmpty == false ? item.overview : meta.description,
            releaseDate: item.releaseDate,
            posterURL: meta.posterURL ?? item.posterURL,
            backdropURL: meta.backdropURL ?? item.backdropURL,
            // Reparatie (A/B-testrapport §27): `genres`/`imdbRating` werden al
            // door de addon geleverd maar gingen voorheen verloren -- vullen nu
            // aan waar het item ze zelf nog niet had.
            genre: item.genre ?? meta.genres?.first,
            rating: item.rating ?? meta.imdbRating,
            catalogItemID: item.catalogItemID
        )
    }

    /// Volledige films-resolutie voor een item dat nog GEEN titel/overview/
    /// poster/backdrop heeft (bv. een Collection-item, dat enkel identiteit
    /// bewaart — spec §17 van de Collections-feature). Anders dan
    /// `enrichedArtwork(for:kind:)` (dat alleen al bestaande presentatievelden
    /// bijwerkt) levert dit ook de titel zelf.
    func resolvedMovie(tmdbID: Int, imdbID: String?) async -> MediaItem? {
        guard let resolved = await resolveMovie(tmdbID: tmdbID, imdbID: imdbID) else { return nil }

        // §58 prioriteit 1: ook voor Collections (dat tot nu toe enkel de collectie-brede
        // override van §50 kende) telt een per-titel poster/backdrop-override boven de
        // automatische resolutie hierboven -- zelfde overlay-patroon als `enrichedArtwork`.
        let canonicalKey = VeyraArtworkOverrideStore.canonicalKey(tmdbID: tmdbID, kind: .movie)
        let overrideStore = VeyraArtworkOverrideStore()
        let posterOverride = overrideStore.resolvedURL(canonicalKey: canonicalKey, type: .poster)
        let backdropOverride = overrideStore.resolvedURL(canonicalKey: canonicalKey, type: .backdrop)
        guard posterOverride != nil || backdropOverride != nil else { return resolved }

        await MetadataDiagnosticsRecorder.log(
            kind: .artwork, canonicalID: "tmdb:\(tmdbID)", sourceSelected: "override", sourceActuallyUsed: "override",
            fallbackUsed: false, cacheHit: false,
            candidateID: [posterOverride?.lastPathComponent, backdropOverride?.lastPathComponent]
                .compactMap { $0 }.joined(separator: ","),
            since: Date()
        )

        return MediaItem(
            id: resolved.id,
            title: resolved.title,
            type: resolved.type,
            imdbID: resolved.imdbID,
            tmdbID: resolved.tmdbID,
            overview: resolved.overview,
            releaseDate: resolved.releaseDate,
            posterURL: posterOverride ?? resolved.posterURL,
            backdropURL: backdropOverride ?? resolved.backdropURL,
            genre: resolved.genre,
            rating: resolved.rating,
            catalogItemID: resolved.catalogItemID
        )
    }

    private func resolveMovie(tmdbID: Int, imdbID: String?) async -> MediaItem? {
        let start = Date()
        let canonicalID = "tmdb:\(tmdbID)"

        switch MetadataSourcePolicy.activeSource() {
        case .aioMetadata(let addon):
            let cacheHit = aioCacheContains(addon: addon, imdbID: imdbID, tmdbID: tmdbID, kind: .movie)
            let addonLabel = "\(addon.name) (\(addon.id.uuidString.prefix(8)))"
            // Reparatie (A/B-testrapport §17/§35): ook via `tmdb:{id}` als er
            // geen IMDb-ID is — bv. Château Planckaert, die zonder deze
            // terugval altijd op TMDB terechtkwam ondanks de gekozen addon.
            if let meta = await resolvedAIOMeta(addon: addon, imdbID: imdbID, tmdbID: tmdbID, kind: .movie) {
                await MetadataDiagnosticsRecorder.log(
                    kind: .metadata, canonicalID: canonicalID, sourceSelected: "aioMetadata",
                    sourceActuallyUsed: "aioMetadata", fallbackUsed: false, cacheHit: cacheHit,
                    addonID: addonLabel, since: start
                )
                return MediaItem(
                    title: meta.name ?? "?",
                    type: .movie,
                    imdbID: imdbID ?? meta.resolvedImdbID,
                    tmdbID: tmdbID,
                    overview: meta.description,
                    releaseDate: meta.releaseInfo,
                    posterURL: meta.posterURL,
                    backdropURL: meta.backdropURL,
                    genre: meta.genres?.first,
                    rating: meta.imdbRating
                )
            }
            let result = await tmdbResolvedMovie(tmdbID: tmdbID, imdbID: imdbID)
            await MetadataDiagnosticsRecorder.log(
                kind: .metadata, canonicalID: canonicalID, sourceSelected: "aioMetadata",
                sourceActuallyUsed: "tmdb", fallbackUsed: true, cacheHit: cacheHit,
                addonID: addonLabel, since: start
            )
            return result

        case .tmdb:
            let result = await tmdbResolvedMovie(tmdbID: tmdbID, imdbID: imdbID)
            await MetadataDiagnosticsRecorder.log(
                kind: .metadata, canonicalID: canonicalID, sourceSelected: "tmdb",
                sourceActuallyUsed: "tmdb", fallbackUsed: false, cacheHit: false, since: start
            )
            return result
        }
    }

    private func tmdbResolvedMovie(tmdbID: Int, imdbID: String?) async -> MediaItem? {
        if let cached = await TMDBMetadataCache.shared.get(tmdbID: tmdbID, kind: .movie) {
            return cached
        }
        guard let token = AppConfiguration.tmdbReadAccessToken,
              let details = try? await TMDBClient(readAccessToken: token).movieDetails(id: tmdbID)
        else { return nil }

        let media = MediaItem(
            title: details.title,
            type: .movie,
            imdbID: imdbID,
            tmdbID: tmdbID,
            overview: details.overview,
            releaseDate: details.releaseDate,
            posterURL: TMDBImageURLBuilder.poster(details.posterPath),
            backdropURL: TMDBImageURLBuilder.backdrop(details.backdropPath),
            genre: details.genres?.first?.name,
            rating: details.voteAverage
        )
        await TMDBMetadataCache.shared.set(tmdbID: tmdbID, kind: .movie, media)
        return media
    }

    // MARK: - TMDB (ongewijzigd overgenomen uit `ShelfCatalogService.enrich` —
    // zelfde gedeelde `TMDBMetadataCache`/`TMDBClient`/`SeriesService`-paden,
    // nu alleen centraal in deze repository i.p.v. in `ShelfCatalogService`.)

    private func tmdbEnriched(_ item: MediaItem, kind: ShelfMediaKind) async -> MediaItem {
        guard let tmdbID = item.tmdbID else { return item }

        if let cached = await TMDBMetadataCache.shared.get(tmdbID: tmdbID, kind: kind) {
            return MediaItem(
                id: item.id,
                title: item.title,
                type: item.type,
                imdbID: item.imdbID,
                tmdbID: item.tmdbID,
                overview: item.overview,
                releaseDate: item.releaseDate,
                posterURL: cached.posterURL,
                backdropURL: cached.backdropURL,
                genre: item.genre ?? cached.genre,
                rating: cached.rating ?? item.rating,
                catalogItemID: item.catalogItemID
            )
        }

        if kind == .movie, let token = AppConfiguration.tmdbReadAccessToken {
            if let details = try? await TMDBClient(readAccessToken: token).movieDetails(id: tmdbID) {
                let enriched = MediaItem(
                    id: item.id,
                    title: item.title,
                    type: item.type,
                    imdbID: item.imdbID,
                    tmdbID: item.tmdbID,
                    overview: item.overview,
                    releaseDate: item.releaseDate,
                    posterURL: TMDBImageURLBuilder.poster(details.posterPath),
                    backdropURL: TMDBImageURLBuilder.backdrop(details.backdropPath),
                    genre: item.genre ?? details.genres?.first?.name,
                    rating: details.voteAverage ?? item.rating,
                    catalogItemID: item.catalogItemID
                )
                await TMDBMetadataCache.shared.set(tmdbID: tmdbID, kind: kind, enriched)
                return enriched
            }
        } else if kind == .series, let service = SeriesService() {
            if let details = try? await service.seriesDetails(id: tmdbID) {
                let enriched = MediaItem(
                    id: item.id,
                    title: item.title,
                    type: item.type,
                    imdbID: item.imdbID,
                    tmdbID: item.tmdbID,
                    overview: item.overview,
                    releaseDate: item.releaseDate,
                    posterURL: TMDBImageURLBuilder.poster(details.posterPath),
                    backdropURL: TMDBImageURLBuilder.backdrop(details.backdropPath),
                    genre: item.genre ?? details.genres?.first?.name,
                    rating: details.voteAverage ?? item.rating,
                    catalogItemID: item.catalogItemID
                )
                await TMDBMetadataCache.shared.set(tmdbID: tmdbID, kind: kind, enriched)
                return enriched
            }
        }

        return item
    }
}
