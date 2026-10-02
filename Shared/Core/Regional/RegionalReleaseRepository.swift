// RegionalReleaseRepository.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 1 (spec §60/§61): cache-first repository voor regionale releases. Zelfde patroon als de
// bestaande EPG/Trakt-snapshot-caches: synchroon de laatst gekende (eventueel verouderde) data
// teruggeven voor directe UI, en pas daarna op de achtergrond verversen via de geregistreerde
// `RegionalReleaseProvider`s (`RegionalReleaseProviderRegistry`). Persistentie via `IPTVDiskCache`
// (spec §77: "app restart mag state niet verliezen") i.p.v. UserDefaults -- zelfde reden als bij
// de EPG/Trakt-cache: dit kan een niet-triviale hoeveelheid genormaliseerde releases bevatten.
import Foundation

actor RegionalReleaseRepository {
    static let shared = RegionalReleaseRepository()

    private init() {}

    private static func cacheKey(region: String) -> String {
        "regional.releases.\(region)"
    }

    /// Spec §29: events met een EXPLICIET gemelde `sourceConfidence` onder deze drempel worden
    /// uit "Nieuw van hier" geweerd (zie `refresh(context:)`) -- vandaag raakt dit geen bestaande
    /// provider (VRT: 0,5, IPTV-VOD: 0,35 liggen beide erboven), maar voorkomt dat een latere,
    /// nog ruwere bron zonder nadenken naast VRT in Home verschijnt.
    private static let minimumSourceConfidence = 0.3

    /// Spec §60: "cached normalized releases -> immediate UI" -- synchrone schijf-lezing, geen
    /// netwerk, geschikt om meteen te tonen bij het openen van "Nieuw van hier".
    nonisolated func cachedEvents(region: String) -> [RegionalReleaseEvent] {
        IPTVDiskCache.read([RegionalReleaseEvent].self, key: Self.cacheKey(region: region))?.value ?? []
    }

    /// Ouderdom van de cache, voor een eventuele "ververst..." / stale-indicator -- `nil` als er
    /// nog nooit gecached is voor deze regio.
    nonisolated func cacheAge(region: String) -> TimeInterval? {
        guard let saved = IPTVDiskCache.read([RegionalReleaseEvent].self, key: Self.cacheKey(region: region))?.savedAt else {
            return nil
        }
        return Date().timeIntervalSince(saved)
    }

    /// Spec §21/§61: haalt alle geregistreerde providers voor `context.region` parallel op, met
    /// per-provider foutisolatie -- één falende bron mag de andere bronnen niet blokkeren, en mag
    /// de bestaande cache nooit wissen (spec §61: "een provider outage mag cached data niet
    /// wissen"). Normaliseert (sortering), dedupliceert en persisteert het resultaat.
    @discardableResult
    func refresh(context: RegionalReleaseContext) async -> [RegionalReleaseEvent] {
        let providers = await RegionalReleaseProviderRegistry.shared.providers(for: context.region)
        guard !providers.isEmpty else {
            // Spec §61 ("successful empty" is geen fout): geen geregistreerde bron is geen reden
            // om de bestaande cache te legen -- geef gewoon terug wat er al was.
            return cachedEvents(region: context.region)
        }

        let fetched = await withTaskGroup(of: [RegionalReleaseEvent].self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return try await provider.releases(context: context)
                    } catch {
                        #if DEBUG
                        print("[Regional] provider=\(provider.id) failed: \(error)")
                        #endif
                        return []
                    }
                }
            }
            var merged: [RegionalReleaseEvent] = []
            for await events in group { merged.append(contentsOf: events) }
            return merged
        }

        // Ondergrens voor `sourceConfidence`. Spec §29 ("lage confidence" mag een item wel tonen)
        // gaat over het individuele event -- dit is een extra vangnet op repository-niveau: een
        // provider die zélf een té lage score meldt (bv. een toekomstige, nog ruwere bron dan
        // `IPTVVODRegionalReleaseProvider`'s 0.35) mag niet zomaar naast VRT's eigen
        // "Binnenkort"-lijst (0.5) in Home verschijnen. `nil` ("geen confidence-signaal") komt
        // hier altijd door; enkel een EXPLICIET te lage score wordt geweerd.
        let confident = fetched.filter { event in
            guard let confidence = event.sourceConfidence else { return true }
            return confidence >= Self.minimumSourceConfidence
        }

        // Spec §61: enkel overschrijven als er daadwerkelijk iets opgehaald is óf er al
        // providers geregistreerd zijn (waardoor een lege uitkomst een bewuste "geen releases
        // deze week" kan zijn) -- hier altijd persisten, want elke individuele provider-fout is
        // hierboven al tot `[]` voor die bron herleid, niet tot het afbreken van de hele refresh.
        let deduped = Self.deduplicated(confident)

        // Fase 3 (spec §15/§28/§29): canonical identity + TMDB-enrichment via de bestaande
        // metadata-stack, ná de goedkope titel-dedupe maar vóór het persisten -- spec §62 ("TMDB
        // failure mag regionale release niet automatisch verwijderen") houdt dit altijd een
        // best-effort verrijking, nooit een reden om events te laten vallen.
        let enriched = await RegionalReleaseTMDBEnricher.enrich(deduped)

        // Spec §90 ("VRT 1" + "VRT MAX" -> één canonical media-item): nu pas, met een betrouwbare
        // `tmdbID` beschikbaar waar mogelijk, kan dezelfde serie over meerdere kanalen/providers
        // heen herkend worden -- de titel-gebaseerde `deduplicated(_:)` hierboven kan dat niet.
        let merged = Self.mergedByIdentity(enriched)

        IPTVDiskCache.write(merged, key: Self.cacheKey(region: context.region))
        return merged
    }

    /// Spec §90: dezelfde serie via meerdere kanalen van dezelfde provider (bv. "VRT 1" +
    /// "VRT MAX") mag niet als twee Home-kaarten verschijnen. Deze eerste pas dedupliceert op een
    /// voorzichtige, titel-gebaseerde sleutel (vóór TMDB-enrichment, dus goedkoop); de striktere
    /// identity-gebaseerde dedupe op `tmdbID` gebeurt hierna in `mergedByIdentity(_:)` (fase 3).
    /// Sorteert meteen ook volgens `RegionalReleaseType.homePriority` (spec §27) zodat een
    /// aanroeper de lijst direct in Home-volgorde krijgt.
    private static func deduplicated(_ events: [RegionalReleaseEvent]) -> [RegionalReleaseEvent] {
        var seen: Set<String> = []
        var result: [RegionalReleaseEvent] = []
        for event in events.sorted(by: { $0.releaseDate < $1.releaseDate }) {
            let key = "\(event.providerID)|\(event.title.lowercased())|\(event.releaseType.rawValue)|\(event.season ?? -1)|\(event.episode ?? -1)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(event)
        }
        return result.sorted { lhs, rhs in
            if lhs.releaseType.homePriority != rhs.releaseType.homePriority {
                return lhs.releaseType.homePriority < rhs.releaseType.homePriority
            }
            // Binnen dezelfde homePriority-tier: een betrouwbaardere bron (bv. VRT's expliciete
            // "Binnenkort"-lijst, 0,5) vóór een indirecte proxy (bv. IPTV-VOD's reseller-
            // "added"-tijdstip, 0,35) -- `nil` ("geen confidence-signaal") krijgt een neutrale
            // middenwaarde, noch voorgetrokken noch achtergesteld.
            let lhsConfidence = lhs.sourceConfidence ?? 0.5
            let rhsConfidence = rhs.sourceConfidence ?? 0.5
            if lhsConfidence != rhsConfidence {
                return lhsConfidence > rhsConfidence
            }
            return lhs.releaseDate < rhs.releaseDate
        }
    }

    /// Fase 3 (spec §90): tweede dedupe-pas ná TMDB-enrichment, op canonical identity i.p.v.
    /// titel -- vangt dezelfde serie via twee kanalen (bv. "VRT 1" + "VRT MAX") ook wanneer de
    /// providers zelf verschillende titels/schrijfwijzen rapporteren. Events zonder `tmdbID`
    /// (geen match gevonden, spec §62) vallen terug op de titel-sleutel van de eerste pas, zodat
    /// ze nooit per ongeluk met een andere, wél gematchte serie samengevoegd worden.
    private static func mergedByIdentity(_ events: [RegionalReleaseEvent]) -> [RegionalReleaseEvent] {
        var seen: Set<String> = []
        var result: [RegionalReleaseEvent] = []
        for event in events {
            let key: String
            if let tmdbID = event.tmdbID {
                key = "tmdb:\(tmdbID)|\(event.releaseType.rawValue)|\(event.season ?? -1)|\(event.episode ?? -1)"
            } else {
                key = "title:\(event.providerID)|\(event.title.lowercased())|\(event.releaseType.rawValue)|\(event.season ?? -1)|\(event.episode ?? -1)"
            }
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(event)
        }
        return result
    }
}
