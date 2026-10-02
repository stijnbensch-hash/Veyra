// RegionalReleaseTMDBEnricher.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 3 ("CANONICAL IDENTITY + TMDB" spec §15/§28/§29/§62): vult `tmdbID`/`imdbID` op een
// `RegionalReleaseEvent` aan via de BESTAANDE metadata-stack (`TMDBExternalLookup`, al gebouwd in
// de TMDB-performance-refactor en hergebruikt in `ShelfCatalogService` voor IPTV) i.p.v. een
// eigen matcher te bouwen -- precies wat de fase-0-audit als hergebruikbaar aanmerkte. Regionale
// providers melden zelf geen IMDb-ID, dus matching gebeurt via titel+jaar (met de bestaande
// titel/jaar-heuristiek in `TMDBExternalLookup.bestMatch`); elke match wordt persistent gecached
// via `IPTVTMDBMappingCache`, dus herhaalde refreshes van dezelfde release kosten geen nieuwe
// TMDB-aanvraag. Spec §62 ("TMDB failure mag regionale release niet automatisch verwijderen"):
// een ontbrekende/mislukte match laat het event gewoon staan met `tmdbID == nil`, nooit een throw
// die de hele refresh zou breken.
import Foundation

enum RegionalReleaseTMDBEnricher {
    /// Spec §66 ("geen network op focus") is hier niet van toepassing -- dit draait enkel tijdens
    /// de achtergrond-`refresh()` van `RegionalReleaseRepository`, nooit vanuit een UI-focus-event.
    /// Begrensde gelijktijdigheid (i.p.v. alles tegelijk) om spec §65/§89 ("geen request storms")
    /// te respecteren, ook al dedupliceert `TMDBRequestCoordinator` toch al gelijke aanvragen.
    private static let maxConcurrent = 4

    static func enrich(_ events: [RegionalReleaseEvent]) async -> [RegionalReleaseEvent] {
        guard !events.isEmpty else { return [] }

        var results = events
        var index = 0
        while index < events.count {
            let chunk = Array(events[index..<min(index + maxConcurrent, events.count)]).enumerated()
            await withTaskGroup(of: (Int, RegionalReleaseEvent).self) { group in
                for (offset, event) in chunk {
                    group.addTask {
                        (index + offset, await Self.enriched(event))
                    }
                }
                for await (position, enrichedEvent) in group {
                    results[position] = enrichedEvent
                }
            }
            index += maxConcurrent
        }
        return results
    }

    /// Spec §29 ("matching moet veilig zijn"): title + original title (indien bekend) + jaar +
    /// type (altijd `.series` -- regionale bronnen rapporteren omroepuitzendingen, geen films) +
    /// bestaande external-ID-heuristiek via `TMDBExternalLookup`. Een event dat al een `tmdbID`
    /// heeft (bv. door een latere, rechtstreekse providerbron) wordt nooit overschreven.
    private static func enriched(_ event: RegionalReleaseEvent) async -> RegionalReleaseEvent {
        var updated = event

        // Sommige providers (bv. `IPTVVODRegionalReleaseProvider`, die zijn TMDB-ID al kant-en-
        // klaar van de IPTV-reseller krijgt) melden zelf al een `tmdbID`. In dat geval slaan we
        // ENKEL de titel/jaar-matchstap hieronder over -- poster/backdrop/imdbID-enrichment
        // (verderop in deze functie) blijft wel lopen, want die hing hiervoor ten onrechte af van
        // dezelfde guard en bleef dus leeg voor zo'n al-opgeloste provider.
        if updated.tmdbID == nil {
            // Enkel voor een echte NIEUWE reeks (of een aankomende première) benadert
            // `releaseDate`'s jaar TMDB's `firstAirDate`-jaar betrouwbaar. Voor een nieuw SEIZOEN
            // (of een losse episode) van een al langer lopende reeks is de uitzenddatum van dat
            // seizoen geen schatting van wanneer de reeks oorspronkelijk startte -- `year` hier toch
            // meegeven liet `TMDBExternalLookup.bestMatch` stil op een andere, gelijknamige titel
            // terugvallen zodra geen enkel zoekresultaat toevallig in dat seizoensjaar lag (bv. de
            // generieke titel "Switch"), wat exact de gerapporteerde "verkeerde metadata" verklaart.
            let year: Int? = {
                switch event.releaseType {
                case .newSeries, .upcomingPremiere: return Calendar.current.component(.year, from: event.releaseDate)
                case .newSeason, .premiere, .episode: return nil
                }
            }()
            guard let tmdbID = await TMDBExternalLookup.tmdbID(
                forIMDbID: event.imdbID,
                title: event.title,
                year: year,
                kind: .series,
                // Zonder jaartal-match valt de matcher anders terug op TMDB's blinde
                // relevantievolgorde -- deze voorkeur voor de regio-eigen taal (spec §55: "regio/taal
                // horen bij de identiteit") vermindert het risico op een foute, gelijknamige
                // buitenlandse titel aanzienlijk, al is het geen garantie bij een echte titelbotsing.
                preferredOriginalLanguage: event.languageCode
            ) else {
                return event
            }
            updated.tmdbID = tmdbID
        }

        guard let tmdbID = updated.tmdbID else { return updated }

        // Best-effort: ook de IMDb-ID erbij halen voor latere canonical identity (fase 7/8/9 --
        // VeyraHub/Trakt reconciliation werkt op canonical identity, niet op providertitels). Een
        // mislukte lookup hier mag de al gevonden `tmdbID` niet ongedaan maken.
        if updated.imdbID == nil, let service = SeriesService() {
            updated.imdbID = try? await service.externalIDs(forSeriesID: tmdbID).imdbID
        }

        // Spec §15: poster/backdrop horen net als de identiteit bij TMDB-enrichment -- hier in
        // één moeite door opgehaald (i.p.v. elk scherm dat zelf opnieuw te laten doen, spec §67),
        // zodat zowel de Home-sectie (fase 4) als Veyra Now (fase 5) er zonder eigen netwerkcode
        // bij kunnen. Een mislukte lookup laat de al gevonden `tmdbID`/`imdbID` gewoon staan.
        if updated.posterPath == nil, updated.backdropPath == nil, let service = SeriesService() {
            if let details = try? await service.seriesDetails(id: tmdbID) {
                updated.posterPath = details.posterPath
                updated.backdropPath = details.backdropPath
            }
        }

        return updated
    }
}
