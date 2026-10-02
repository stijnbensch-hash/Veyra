// IPTVVODRegionalReleaseProvider.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 12 (vervolg, "VEYRA — REGIONAL RELEASES" spec §19): een TWEEDE, optionele
// `RegionalReleaseProvider` naast `VRTRegionalReleaseProvider`, die GEEN enkele broadcaster-site
// aanroept of scraped. In plaats daarvan leest hij uit de VOD/series-catalogus van het
// IPTV/Xtream-account dat de gebruiker zelf al configureerde in "Mediaservers"
// (`IPTVConfigurationStore`) -- dezelfde bron die ook de bestaande Live TV/EPG en VOD-shelves
// voedt. Geen eigen credentials, geen eigen aanmeldscherm, geen ToS-risico: dit is simpelweg het
// reeds betaalde abonnement van de gebruiker, nooit een publieke pagina van VTM/Play/Streamz/VRT
// zelf.
//
// Herkomst/verificatie (live getest 2026-10-02 op een reëel Xtream-panel, één keer, met
// expliciete toestemming van de gebruiker -- zie gespreksgeschiedenis):
// - `XtreamClient.seriesCategories()` + `.series(categoryID:)` leveren per Belgische zender een
//   eigen VOD-categorie (bv. "┃BE┃ VRT MAX", "┃BE┃ VTMGO+", "┃BE┃ STREAMZ", "┃BE┃ GO PLAY"). De
//   exacte naam/casing/spatiëring verschilt per IPTV-reseller -- vandaar `brandMarkers` hieronder
//   als losse, caseless substring-matchers, nooit een vaste categorie-ID.
// - Zulke series dragen vaak al een TMDB-ID die de reseller zelf oploste (`XtreamSeriesItem.tmdbID`)
//   -- rechtstreeks doorgegeven aan `RegionalReleaseEvent.tmdbID`, zodat
//   `RegionalReleaseTMDBEnricher` zijn titel/jaar-matchstap overslaat (die zou een al correcte ID
//   met een fuzzy match kunnen overschrijven) maar poster/backdrop/imdbID alsnog aanvult.
// - `XtreamClient.seriesInfo(seriesID:)` geeft per aflevering een "added"-tijdstip: het moment
//   waarop DEZE RESELLER de aflevering aan zijn catalogus toevoegde. Dat is geen garantie-perfecte
//   proxy voor de officiële premièredatum (reseller-vertraging mogelijk) -- vandaar een lagere
//   `sourceConfidence` dan `VRTRegionalReleaseProvider` (die een expliciete "Binnenkort"-lijst
//   leest), maar het is het enige structurele "nieuw beschikbaar"-signaal dat deze bron biedt.
//
// Belangrijk: GEEN universele provider. Hij is alleen nuttig als de gebruiker al een Xtream-
// account heeft MET zo'n providerspecifieke categorie -- niet elke IPTV-reseller curate't zijn
// VOD-catalogus zo. Geen account, geen Xtream-configuratie, of geen matchende categorie → lege
// lijst, nooit een `throw` (spec §21: "één provider failure mag andere providers niet breken",
// hier: geen data is geen failure).
import Foundation

nonisolated struct IPTVVODRegionalReleaseProvider: RegionalReleaseProvider {
    let id = "iptv-vod"
    let displayName = "IPTV VOD (eigen abonnement)"
    let supportedRegions: Set<String> = [RegionalReleaseContext.defaultRegion]

    /// Herkenning van providermerken in een Xtream-categorienaam -- caseless substring-match,
    /// omdat IPTV-resellers zelf geen vaste naamconventie volgen (zie live-geverifieerde namen
    /// hierboven). `providerID` komt hier terecht in `RegionalReleaseEvent.providerID`, dus moet
    /// dezelfde stabiele, lage-case sleutel zijn als elders (`"vrt"`, `"vtm"`, `"streamz"`,
    /// `"goplay"`).
    private static let brandMarkers: [(providerID: String, markers: [String])] = [
        ("vrt", ["VRT MAX", "VRTMAX"]),
        ("vtm", ["VTMGO", "VTM GO"]),
        ("streamz", ["STREAMZ"]),
        ("goplay", ["GO PLAY", "GOPLAY"]),
    ]

    /// Hoeveel dagen terug een serie/episode "added"-tijdstip nog als potentieel nieuw telt.
    /// Ruimer dan `context.windowDays` omdat deze provider geen live polling doet (enkel bij
    /// `RegionalReleaseRepository.refresh()`) -- een iets ruimer venster voorkomt dat een traag
    /// verversende catalogus een echt nieuwe aflevering net mist.
    private static let freshnessWindowDays = 14

    func releases(context: RegionalReleaseContext) async throws -> [RegionalReleaseEvent] {
        // Instellingen → Home → Nieuw van hier: expliciete uitzetknop voor deze aanvullende,
        // lagere-confidence bron, los van VRT (zie RegionalReleaseSettings.swift).
        guard RegionalReleaseSettingsStore().load().showIPTVVODReleases else {
            return []
        }

        guard let configurations = Self.xtreamConfigurations(), !configurations.isEmpty else {
            return []
        }

        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -Self.freshnessWindowDays,
            to: context.windowStart
        ) ?? context.windowStart

        var events: [RegionalReleaseEvent] = []

        for (accountIndex, configuration) in configurations.enumerated() {
            let client = XtreamClient(configuration: configuration)

            let categories: [IPTVCategory]
            do {
                categories = try await client.seriesCategories()
            } catch {
                // Eén falend Xtream-account mag andere accounts/providers niet blokkeren.
                continue
            }

            let matched = Self.matchBrandedCategories(categories)
            guard !matched.isEmpty else { continue }

            for (providerID, category) in matched {
                let seriesItems: [XtreamSeriesItem]
                do {
                    seriesItems = try await client.series(categoryID: category.id)
                } catch {
                    continue
                }

                // Alleen series die recent genoeg gewijzigd zijn verdienen een duurdere
                // `seriesInfo(seriesID:)`-aanroep per serie -- niet de hele catalogus bevragen
                // als er op series-niveau al geen enkel vers signaal is.
                let recentSeries = seriesItems.filter { item in
                    guard let added = item.added else { return false }
                    return added >= cutoff
                }

                for seriesItem in recentSeries {
                    guard let event = await Self.event(
                        for: seriesItem,
                        providerID: providerID,
                        accountIndex: accountIndex,
                        client: client,
                        context: context,
                        cutoff: cutoff
                    ) else { continue }
                    events.append(event)
                }
            }
        }

        return events
    }

    // MARK: - Categorie-matching

    private static func matchBrandedCategories(
        _ categories: [IPTVCategory]
    ) -> [(providerID: String, category: IPTVCategory)] {
        var result: [(providerID: String, category: IPTVCategory)] = []
        for category in categories {
            let upper = category.name.uppercased()
            for (providerID, markers) in brandMarkers {
                if markers.contains(where: { upper.contains($0) }) {
                    result.append((providerID, category))
                    break
                }
            }
        }
        return result
    }

    // MARK: - Event-opbouw

    private static func event(
        for seriesItem: XtreamSeriesItem,
        providerID: String,
        accountIndex: Int,
        client: XtreamClient,
        context: RegionalReleaseContext,
        cutoff: Date
    ) async -> RegionalReleaseEvent? {
        guard let info = try? await client.seriesInfo(seriesID: seriesItem.id) else {
            return nil
        }

        let recentEpisodes = info.episodes.filter { episode in
            guard let added = episode.added else { return false }
            return added >= cutoff
        }
        guard let newestEpisode = recentEpisodes.max(by: {
            ($0.added ?? .distantPast) < ($1.added ?? .distantPast)
        }) else {
            return nil
        }

        let releaseType: RegionalReleaseType
        if newestEpisode.seasonNumber <= 1, newestEpisode.episodeNumber == 1 {
            releaseType = .newSeries
        } else if newestEpisode.episodeNumber == 1 {
            releaseType = .newSeason
        } else {
            releaseType = .episode
        }

        let releaseDate = newestEpisode.added ?? seriesItem.added ?? context.windowStart

        // Accountindex in de id zodat series_id-botsingen tussen twee verschillende
        // Xtream-accounts van de gebruiker (zelden, maar mogelijk) geen events laten overschrijven.
        return RegionalReleaseEvent(
            id: "iptv-vod:\(accountIndex):\(providerID):\(seriesItem.id)",
            tmdbID: seriesItem.tmdbID,
            providerID: providerID,
            channelID: nil,
            region: context.region,
            countryCode: context.countryCode,
            languageCode: context.languageCode,
            title: Self.cleanTitle(seriesItem.name),
            originalTitle: nil,
            releaseType: releaseType,
            releaseDate: releaseDate,
            airDate: nil,
            season: newestEpisode.seasonNumber,
            episode: newestEpisode.episodeNumber,
            // Lager dan VRT (0.5): een reseller-"added"-tijdstip is een indirecte proxy voor de
            // officiële premièredatum, geen expliciete "Binnenkort"-vermelding -- zie uitleg
            // bovenaan dit bestand.
            sourceConfidence: 0.35
        )
    }

    /// IPTV-resellers zetten vaak een land-/merkprefix (bv. "┃BE┃ ") en/of een los jaartal
    /// (bv. "(2026)") in de series-naam -- geen van beide hoort in de titel die
    /// `VeyraBentoPosterContent` toont.
    private static func cleanTitle(_ raw: String) -> String {
        var result = raw
        if let range = result.range(of: #"^[┃|][^┃|]*[┃|]\s*"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        if let range = result.range(of: #"\s*\(\d{4}\)\s*$"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Configuratie

    /// Alle door de gebruiker geconfigureerde Xtream-accounts (spec: deze provider is per-
    /// gebruiker optioneel en heeft geen eigen credentials -- hergebruikt gewoon wat al in
    /// "Mediaservers" staat). `nil`/leeg als er geen enkele Xtream-account is, of als de
    /// Keychain-opslag niet leesbaar is -- behandeld als "geen data", nooit als fout.
    private static func xtreamConfigurations() -> [XtreamConfiguration]? {
        guard let providers = try? IPTVConfigurationStore().loadProviders() else {
            return nil
        }
        let configurations = providers.compactMap { provider in
            if case .xtream(let configuration) = provider.configuration {
                return configuration
            }
            return nil
        }
        return configurations.isEmpty ? nil : configurations
    }
}
