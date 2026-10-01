// VeyraCollectionModels.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Datamodel voor "Veyra Collections" (eigen + officiële filmcollecties) -- Fase 2.
// Zie de Collections-specificatie: hergebruikt bestaande MediaItem/tmdbID/imdbID als canonical
// identiteit (spec §16), bewaart GEEN gedupliceerde metadata per item (spec §17) -- enkel
// identiteit + collectie-eigen velden (titel/poster/overview worden elders in Veyra opgelost).
// Bewust ONDERSCHEIDEN van `BentoCollectionEntry`/`VeyraCollectionsStore`
// (VeyraBentoCatalog.swift): dat is een TMDB-collectie-ID-gebaseerde Home-rij, dit hier is een
// user-curated lijst van losse films (met eigen items, volgorde, naam, beschrijving).

import Foundation

/// Hoe een collectie is ontstaan.
enum VeyraCollectionType: String, Codable, Hashable {
    case manual
    case official
    case imported
    // `smart` komt later (spec §60) -- nu nog NIET gebruiken, enkel de opslagvorm
    // (String-raw-value enum, los veld op `VeyraCollection`) er klaar voor laten zijn.
}

/// Hoe de films binnen een collectie gesorteerd worden (spec §11/§30).
enum VeyraCollectionSortMode: String, Codable, Hashable {
    case manual
    case releaseDate
    case title
    case dateAdded
    /// Verhaal-/universe-chronologie -- NIET hetzelfde als `releaseDate` (spec §35: "NIET:
    /// releasedatum"). Wordt nooit automatisch gegokt (spec §36) -- enkel expliciet door de
    /// gebruiker ingesteld via de chronologie-editor, zie `VeyraCollectionItem.chronologyIndex`.
    case chronological
}

/// Positie/crop voor collectie-artwork (spec §59) -- `x`/`y` zijn 0...1 (relatief, 0.5 = midden),
/// `zoom` >= 1 (1 = geen extra inzoom).
struct VeyraArtworkPosition: Codable, Hashable {
    var x: Double = 0.5
    var y: Double = 0.5
    var zoom: Double = 1.0
}

/// Eén film binnen een collectie. Bewaart BEWUST geen titel/poster/overview/cast/stream-URL's --
/// die worden elders in Veyra opgelost via `mediaID`/`tmdbID`/`imdbID` (spec §17). Collectie-
/// lidmaatschap is dus onafhankelijk van welke IPTV-bron een film op dit moment levert (spec §16/§45).
struct VeyraCollectionItem: Codable, Identifiable, Hashable {
    let id: UUID

    /// Canonical media-ID (zie `canonicalMediaID(for:)`) -- stabiel ongeacht welke IPTV-provider
    /// de film op dit moment levert.
    let mediaID: String
    let mediaType: MediaType

    let tmdbID: Int?
    let imdbID: String?

    let addedAt: Date
    var manualSortIndex: Int
    /// Losstaand van `manualSortIndex` (spec §37: "gebruik niet hetzelfde veld... want deze
    /// betekenen iets anders") -- `nil` zolang de gebruiker nog geen chronologie heeft ingesteld
    /// voor deze collectie (spec §36: nooit gegokt, enkel expliciet user-defined).
    var chronologyIndex: Int?

    init(id: UUID = UUID(), mediaID: String, mediaType: MediaType, tmdbID: Int? = nil, imdbID: String? = nil,
         addedAt: Date = Date(), manualSortIndex: Int, chronologyIndex: Int? = nil) {
        self.id = id
        self.mediaID = mediaID
        self.mediaType = mediaType
        self.tmdbID = tmdbID
        self.imdbID = imdbID
        self.addedAt = addedAt
        self.manualSortIndex = manualSortIndex
        self.chronologyIndex = chronologyIndex
    }

    /// Bouwt een collectie-item uit een bestaand `MediaItem` -- de enige plek waar een
    /// `MediaItem` naar collectie-identiteit wordt omgezet (spec §15/§16).
    init(item: MediaItem, manualSortIndex: Int) {
        self.id = UUID()
        self.mediaID = Self.canonicalMediaID(for: item)
        self.mediaType = item.type
        self.tmdbID = item.tmdbID
        self.imdbID = item.imdbID
        self.addedAt = Date()
        self.manualSortIndex = manualSortIndex
        self.chronologyIndex = nil
    }

    /// Prioriteit: TMDB -> IMDb -> providerspecifieke catalogus-ID -> lokale UUID als laatste
    /// terugval (spec §16) -- nooit een IPTV-stream-URL, zodat een providerwissel de
    /// collectie-identiteit niet breekt (spec §45).
    static func canonicalMediaID(for item: MediaItem) -> String {
        if let tmdb = item.tmdbID { return "tmdb:\(tmdb)" }
        if let imdb = item.imdbID, !imdb.isEmpty { return "imdb:\(imdb)" }
        if let catalogID = item.catalogItemID, !catalogID.isEmpty { return "catalog:\(catalogID)" }
        return "local:\(item.id.uuidString)"
    }

    /// Duplicate-detectie (spec §42/§43): zelfde canonical identiteit, ongeacht welke velden
    /// toevallig bekend zijn op de meegegeven `MediaItem`.
    func matches(_ item: MediaItem) -> Bool {
        if mediaID == Self.canonicalMediaID(for: item) { return true }
        if let tmdbID, let itemTMDB = item.tmdbID, tmdbID == itemTMDB { return true }
        if let imdbID, !imdbID.isEmpty, let itemIMDB = item.imdbID, imdbID == itemIMDB { return true }
        return false
    }
}

/// Eén collectie (eigen of officieel bewaard). Sync-vriendelijk vanaf het begin (spec §58):
/// stabiele `id`, `updatedAt` voor reconciliatie -- geen video data/stream-URL's/afbeelding-binaries.
struct VeyraCollection: Codable, Identifiable, Hashable {
    let id: UUID

    var name: String
    var collectionDescription: String?

    var type: VeyraCollectionType

    var items: [VeyraCollectionItem]

    var sortMode: VeyraCollectionSortMode

    /// Verwijzing naar artwork (bestandsnaam in `VeyraCollectionArtworkStore.imagesDirectory`, of
    /// een https-URL -- TMDB-/fanart.tv-afbeeldingen zijn stabiele publieke CDN-paden, geen
    /// tijdelijke signed URL's, dus permanent genoeg om rechtstreeks te bewaren, zelfde opzet als
    /// `BentoCollectionEntry.customImage`). `nil` = automatische fallback (spec §8/§10): backdrop
    /// van eerste film -> Veyra-placeholder. Dezelfde referentie wordt overal gebruikt (browser,
    /// Home, Continue, Detail Stage -- spec §7 "one collection = one artwork identity") via
    /// `VeyraCollectionArtworkResolver`.
    var artworkReference: String?
    /// Positionering/crop van `artworkReference` (spec §59) -- enkel zinvol bij een expliciet
    /// gekozen afbeelding; `nil` = gecentreerd/standaard.
    var artworkPosition: VeyraArtworkPosition?

    /// Zelfde opzet als `artworkReference`, maar voor het clearlogo op kaarten/Stage i.p.v. de
    /// titel-tekst (bestandsnaam of https-URL). `nil` = automatisch: TMDB-clearlogo van het meest
    /// prominente deel (enkel op de Stage, via `VeyraClearLogo`/`ClearLogoService` -- NIET per
    /// kaart in een raster, dat zou opnieuw de "te veel gelijktijdige TMDB-aanvragen"-traagheid
    /// introduceren die `VeyraCollectionMetadataCache` net oploste), anders gewoon de titel-tekst.
    var clearLogoReference: String?

    /// Voor officiële collecties die uit TMDB komen (spec §33/§34) -- `nil` voor eigen collecties.
    var tmdbCollectionID: Int?

    /// Gezet wanneer deze collectie een persoonlijke kopie is van een officiële collectie
    /// (spec §35/§36) -- de originele officiële collectie blijft in dat geval onaangetast.
    var copiedFromTMDBCollectionID: Int?

    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, collectionDescription: String? = nil,
         type: VeyraCollectionType = .manual, items: [VeyraCollectionItem] = [],
         sortMode: VeyraCollectionSortMode = .manual, artworkReference: String? = nil,
         artworkPosition: VeyraArtworkPosition? = nil, clearLogoReference: String? = nil,
         tmdbCollectionID: Int? = nil, copiedFromTMDBCollectionID: Int? = nil,
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.collectionDescription = collectionDescription
        self.type = type
        self.items = items
        self.sortMode = sortMode
        self.artworkReference = artworkReference
        self.artworkPosition = artworkPosition
        self.clearLogoReference = clearLogoReference
        self.tmdbCollectionID = tmdbCollectionID
        self.copiedFromTMDBCollectionID = copiedFromTMDBCollectionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Items in weergavevolgorde volgens `sortMode` -- `manual`/`dateAdded` zijn hier volledig
    /// zelfvoorzienend; `releaseDate`/`title` vereisen opgeloste metadata die dit model bewust
    /// niet bewaart (spec §17) -- de UI-laag sorteert die twee zelf na het ophalen via de
    /// catalog/metadata-laag, hier blijft de toevoegvolgorde als stabiele basis.
    var orderedItems: [VeyraCollectionItem] {
        switch sortMode {
        case .manual, .releaseDate, .title, .chronological:
            // `releaseDate`/`title`/`chronological` vereisen opgeloste metadata (of, voor
            // chronological, user-defined volgorde) die dit model bewust niet bewaart/afdwingt --
            // de UI-laag sorteert die na het ophalen via de metadata-laag (zie
            // `VeyraCollectionDetailView.orderedResolved`); hier blijft de toevoegvolgorde
            // (manualSortIndex) als stabiele basis.
            return items.sorted { $0.manualSortIndex < $1.manualSortIndex }
        case .dateAdded:
            return items.sorted { $0.addedAt < $1.addedAt }
        }
    }

    var isEmpty: Bool { items.isEmpty }
}
