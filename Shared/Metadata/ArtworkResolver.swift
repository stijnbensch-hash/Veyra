import Foundation

/// Centrale artwork-resolutie (spec "METADATA + AIOMETADATA + ARTWORK ENGINE"
/// Fase 3, §29/§30): vervangt de rechtstreekse `ClearLogoService`-aanroep in
/// `VeyraClearLogo` door een bronbewuste resolver die, bij een gekozen
/// AIOMetadata-addon, eerst diens `logo`-veld gebruikt (Fase 2-reparatie) en
/// anders op TMDB terugvalt (§19) — zodat Detail/Hero/Collection-Stage niet
/// langer altijd TMDB laten zien, ongeacht de gekozen metadatabron.
///
/// Dit is bewust stap 1 van Fase 3: alleen ClearLogo, alleen voor de
/// bestaande `VeyraClearLogo`-aanroepers. `VeyraTMDBArtwork` (Bento, met zijn
/// eigen fanart.tv-pad) en "Nieuw van hier" volgen in latere stappen (zie
/// Fase 3-onderzoeksrapport).
actor ArtworkResolver {
    static let shared = ArtworkResolver()

    private struct TMDBLogoKey: Hashable {
        let tmdbID: Int
        let kind: ShelfMediaKind
    }

    // Cache + dedup voor de TMDB-kant, zelfde patroon als `MetadataRepository`
    // (§22/§24) — `ClearLogoService` deed voorheen bij elke aanroep een
    // nieuwe `/images`-aanvraag, ook als meerdere views dezelfde titel tonen.
    private var tmdbLogoCache: [TMDBLogoKey: URL?] = [:]
    private var tmdbLogoInFlight: [TMDBLogoKey: Task<URL?, Never>] = [:]

    func clearLogoURL(for item: MediaItem) async -> URL? {
        let kind: ShelfMediaKind = item.type == .series ? .series : .movie
        let canonicalID = item.tmdbID.map { "tmdb:\($0)" } ?? (item.imdbID ?? "?")
        let start = Date()
        let language = ArtworkSettingsStore().load().language.rawValue

        // §58 prioriteit 1: een handmatig gekozen candidate voor DEZE titel staat boven alles --
        // ook boven de globale "Altijd tekst"-instelling, want de gebruiker koos hier bewust
        // een specifiek logo voor deze ene titel.
        if let tmdbID = item.tmdbID {
            let canonicalKey = VeyraArtworkOverrideStore.canonicalKey(tmdbID: tmdbID, kind: kind)
            if let url = VeyraArtworkOverrideStore().resolvedURL(canonicalKey: canonicalKey, type: .clearLogo) {
                await MetadataDiagnosticsRecorder.log(
                    kind: .artwork, canonicalID: canonicalID, sourceSelected: "override",
                    sourceActuallyUsed: "override", fallbackUsed: false, cacheHit: false,
                    candidateID: url.lastPathComponent, language: language, since: start
                )
                return url
            }
        }

        // Fase 3 stap 4 (artwork-engine-spec §40): bij "Altijd tekst" meteen stoppen -- geen
        // enkele aanroeper hoeft dan nog een logo te tonen, dus de netwerkaanvraag overslaan
        // i.p.v. het resultaat achteraf te negeren.
        guard ArtworkSettingsStore().load().titleDisplay != .alwaysText else { return nil }

        switch MetadataSourcePolicy.activeSource() {
        case .aioMetadata(let addon):
            let addonLabel = "\(addon.name) (\(addon.id.uuidString.prefix(8)))"
            if let url = await MetadataRepository.shared.aioLogoURL(for: item, kind: kind) {
                await MetadataDiagnosticsRecorder.log(
                    kind: .artwork, canonicalID: canonicalID, sourceSelected: "aioMetadata",
                    sourceActuallyUsed: "aioMetadata", fallbackUsed: false, cacheHit: false,
                    addonID: addonLabel, candidateID: url.lastPathComponent, language: language, since: start
                )
                return url
            }
            // §19: geen logo van de addon (of addon faalde) → TMDB-terugval,
            // zonder de opgeslagen voorkeur te wijzigen (§20).
            let (fallbackURL, hit) = await tmdbLogoURL(for: item, kind: kind)
            await MetadataDiagnosticsRecorder.log(
                kind: .artwork, canonicalID: canonicalID, sourceSelected: "aioMetadata",
                sourceActuallyUsed: "tmdb", fallbackUsed: true, cacheHit: hit,
                addonID: addonLabel, candidateID: fallbackURL?.lastPathComponent, language: language, since: start
            )
            return fallbackURL

        case .tmdb:
            let (url, hit) = await tmdbLogoURL(for: item, kind: kind)
            await MetadataDiagnosticsRecorder.log(
                kind: .artwork, canonicalID: canonicalID, sourceSelected: "tmdb",
                sourceActuallyUsed: "tmdb", fallbackUsed: false, cacheHit: hit,
                candidateID: url?.lastPathComponent, language: language, since: start
            )
            return url
        }
    }

    /// Geeft ook of het resultaat uit de lokale cache kwam (§73 "Cache hit/miss").
    private func tmdbLogoURL(for item: MediaItem, kind: ShelfMediaKind) async -> (URL?, Bool) {
        guard let tmdbID = item.tmdbID else { return (nil, false) }
        let key = TMDBLogoKey(tmdbID: tmdbID, kind: kind)

        if let cached = tmdbLogoCache[key] {
            return (cached, true)
        }
        if let running = tmdbLogoInFlight[key] {
            return (await running.value, false)
        }

        let task = Task<URL?, Never> { [item] in
            await ClearLogoService.logoURL(for: item)
        }
        tmdbLogoInFlight[key] = task

        let result = await task.value
        tmdbLogoInFlight[key] = nil
        tmdbLogoCache[key] = result
        return (result, false)
    }
}
