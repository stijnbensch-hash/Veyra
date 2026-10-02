// RegionalReleaseModels.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 1 ("VEYRA — REGIONAL RELEASES / NIEUW VAN HIER" spec §1/§26/§27): minimaal domeinmodel
// voor een regionale release-gebeurtenis (bv. "Serie X start vandaag op VRT"). Bewust GEEN
// `mediaIdentity: VeyraMediaIdentity`-veld zoals het conceptuele voorbeeld in de spec -- die
// canonical identity-wrapper bestaat nergens in Veyra (zie fase 0-audit: `MediaItem` is het
// dichtstbijzijnde canonical type, maar is zelf niet `Codable` en draagt al UI-klare velden zoals
// poster-/backdrop-URL's). In plaats daarvan dragen `tmdbID`/`imdbID` hier de ruwe, nog mogelijk
// onopgeloste identiteit; fase 3 (canonical identity + TMDB) voegt de matching toe die dit vult
// en converteert een opgelost event naar een `MediaItem` (via `TMDBExternalLookup`, al gebouwd
// in de TMDB-performance-refactor).
import Foundation

/// Spec §27: ordening bepaalt de Home-prioriteit binnen "Nieuw van hier"
/// (`homePriority`, laag = eerst) -- newSeries vóór newSeason vóór premiere/upcomingPremiere
/// vóór een losse episode (spec §12: de sectie mag niet overspoeld worden door S01E02/E03/...).
nonisolated enum RegionalReleaseType: String, Codable, CaseIterable, Hashable, Sendable {
    case newSeries
    case newSeason
    case premiere
    case upcomingPremiere
    case episode

    var homePriority: Int {
        switch self {
        case .newSeries: return 0
        case .newSeason: return 1
        case .premiere: return 2
        case .upcomingPremiere: return 3
        case .episode: return 4
        }
    }
}

/// Eén regionale release-gebeurtenis zoals een `RegionalReleaseProvider` die rapporteert (spec
/// §14: "regionale bron is de release-waarheid" -- dit is de ENIGE plek waar Veyra "dit is
/// vandaag/binnenkort regionaal nieuw" vastlegt, nooit afgeleid uit TMDB/Trakt Trending).
/// `Codable`/`Sendable` zodat dit zowel via `IPTVDiskCache` gepersisteerd als cross-actor
/// doorgegeven kan worden.
nonisolated struct RegionalReleaseEvent: Codable, Identifiable, Hashable, Sendable {
    /// Stabiele id, door de provider zelf bepaald (bv. "vrt:12345" of een content-hash van
    /// titel+providerID+releaseType) -- NOOIT een stream-URL (spec §28: "nooit stream URL als
    /// media identity").
    let id: String

    /// Nog onopgeloste/ruwe identiteit -- `nil` totdat fase 3 (TMDB-matching) dit invult.
    var tmdbID: Int?
    var imdbID: String?

    /// Spec §15 ("TMDB wordt gebruikt voor enrichment/identity: ... poster, backdrop ...") --
    /// net als `tmdbID`/`imdbID` hierboven pas gevuld ná fase-3-matching
    /// (`RegionalReleaseTMDBEnricher`), nooit door de provider zelf. Ruwe TMDB-paden (bv.
    /// "/abc123.jpg"), bewust geen kant-en-klare `URL` -- `TMDBImageURLBuilder` bouwt die pas bij
    /// gebruik, net als overal elders (spec §67: "geen parallelle image-architectuur").
    var posterPath: String?
    var backdropPath: String?

    /// Spec §19: welke `RegionalReleaseProvider` dit gerapporteerd heeft, plus optioneel het
    /// concrete uitzendkanaal (voor "Kijk live", spec §32/§58 -- enkel gebruikt als dit kanaal
    /// ook écht in Veyra's bestaande Live TV/EPG bekend is, zie `IPTVProviderPreferences`).
    let providerID: String
    let channelID: String?

    /// Spec §54/§55: regio/taal zijn onderdeel van de identiteit van een release, niet enkel een
    /// weergavedetail -- bepalen mee of/hoe dit opnieuw opgehaald moet worden bij taalwijziging.
    let region: String
    let countryCode: String
    let languageCode: String

    let title: String
    let originalTitle: String?

    let releaseType: RegionalReleaseType

    let releaseDate: Date
    /// Exacte uitzend-/premièretijd, indien bekend (spec §32: "Vanavond 20:40 • VTM").
    let airDate: Date?

    let season: Int?
    let episode: Int?

    /// Spec §29: bij lage confidence geen destructieve Trakt-sync, item mag "pending" blijven --
    /// `nil` betekent "provider geeft geen confidence-signaal", niet automatisch hoge zekerheid.
    let sourceConfidence: Double?

    init(
        id: String,
        tmdbID: Int? = nil,
        imdbID: String? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        providerID: String,
        channelID: String? = nil,
        region: String,
        countryCode: String,
        languageCode: String,
        title: String,
        originalTitle: String? = nil,
        releaseType: RegionalReleaseType,
        releaseDate: Date,
        airDate: Date? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        sourceConfidence: Double? = nil
    ) {
        self.id = id
        self.tmdbID = tmdbID
        self.imdbID = imdbID
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.providerID = providerID
        self.channelID = channelID
        self.region = region
        self.countryCode = countryCode
        self.languageCode = languageCode
        self.title = title
        self.originalTitle = originalTitle
        self.releaseType = releaseType
        self.releaseDate = releaseDate
        self.airDate = airDate
        self.season = season
        self.episode = episode
        self.sourceConfidence = sourceConfidence
    }
}

/// Spec §19: input voor `RegionalReleaseProvider.releases(context:)` -- een registry/adapter-
/// aanpak i.p.v. `if country == "BE" { loadVRT() }`, zodat een latere Duitse/Nederlandse/Franse/
/// Britse bron zonder wijzigingen aan de core kan aansluiten.
nonisolated struct RegionalReleaseContext: Hashable, Sendable {
    let region: String
    let countryCode: String
    let languageCode: String

    /// Venster waarbinnen releases opgevraagd worden (bv. "laatste 3 dagen t/m komende 14
    /// dagen"), zodat een provider niet zijn volledige historie hoeft terug te geven.
    let windowStart: Date
    let windowDays: Int

    init(region: String, countryCode: String, languageCode: String, windowStart: Date = Date(), windowDays: Int = 14) {
        self.region = region
        self.countryCode = countryCode
        self.languageCode = languageCode
        self.windowStart = windowStart
        self.windowDays = windowDays
    }
}

extension RegionalReleaseContext {
    /// Spec §20: "Eerste implementatie: België / Vlaanderen / Nederlands" -- de gehardcode default
    /// totdat fase 22 (Instellingen) een gebruikersgekozen regio toevoegt. Gedeeld door
    /// `MockRegionalReleaseProvider`'s registratie (`VeyraApp.swift` e.a.) en `VeyraBentoViewModel`
    /// (Home), zodat beide altijd dezelfde regio-sleutel gebruiken.
    static let defaultRegion = "BE-VL"

    static func defaultBelgiumFlanders() -> RegionalReleaseContext {
        RegionalReleaseContext(region: defaultRegion, countryCode: "BE", languageCode: "nl")
    }
}
