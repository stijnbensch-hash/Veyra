import Foundation

/// Soorten overslaanbare segmenten die Veyra's player kent. Nieuwe bronnen
/// (SkipDB, server-markers, ...) leveren allemaal dit type aan -- de Player
/// kent zelf geen enkele bron, alleen dit uniforme model (zie
/// `VeyraSkipSegmentProvider.swift`, spec "Multi-source skip segment
/// system" §129: "Player weet alleen van Veyra-segmenten").
enum VeyraSkipSegmentType: String, Codable, Hashable, Sendable {
    case intro
    case recap
    case credits
    case preview
    case commercial
}

extension VeyraSkipSegmentType {
    /// Kort label voor scrub-context (spec "Skip segments op bestaande progressbar" §25) --
    /// bewust anders dan de skip-knoptekst ("Intro overslaan" e.d.), hier gaat het om een
    /// kort label naast de scrub-tijd, geen actie-knop.
    var shortLabel: String {
        switch self {
        case .intro: return "Intro"
        case .recap: return "Samenvatting"
        case .credits: return "Aftiteling"
        case .preview: return "Preview"
        case .commercial: return "Reclame"
        }
    }
}

/// Waar een `VeyraSkipSegment` vandaan komt -- uitsluitend technische
/// metadata (debug-logging, resolver-prioriteit/dedupe), nooit aan de
/// gewone gebruiker getoond (spec §71: "INTRO OVERSLAAN", niet
/// "INTRO OVERSLAAN — TheIntroDB").
enum VeyraSkipSegmentSource: String, Codable, Hashable, Sendable {
    case theIntroDB
    case skipDB
    case serverMarker
    case chapter
}

/// Eén overslaanbaar segment, in Veyra's eigen, bronneutrale vorm. `start`/
/// `end` zijn ALTIJD seconden vanaf het begin van de video; `nil` betekent
/// "begin van de media" (bij `start`) resp. "einde van de media" (bij
/// `end`) -- zie `contains(_:)` en spec §16.
struct VeyraSkipSegment: Identifiable, Hashable, Sendable {
    let id: String
    let type: VeyraSkipSegmentType
    let start: TimeInterval?
    let end: TimeInterval?
    let source: VeyraSkipSegmentSource
    /// Niet aan de gebruiker getoond (spec §52) -- enkel gebruikt door de
    /// resolver (dedupe/auto-skip-beleid) en in DEBUG-diagnostiek.
    let confidence: Double?

    func contains(_ time: TimeInterval) -> Bool {
        if let start, time < start { return false }
        if let end, time >= end { return false }
        return start != nil || end != nil
    }
}

/// Identificeert WELKE media een opzoeking betreft -- nooit een stream-/
/// afspeel-URL (spec §11): dezelfde aflevering kan via verschillende
/// bronnen worden afgespeeld, maar hoort bij dezelfde skip-markers.
struct VeyraSkipMediaIdentity: Sendable {
    let tmdbID: Int?
    let imdbID: String?
    let season: Int?
    let episode: Int?
    /// Afspeelduur op het moment van opzoeken, voor providers die hiermee
    /// kunnen matchen op de juiste release (spec §18/19). Niet gebruikt
    /// als harde identiteit, zie `durationBucket`.
    let duration: TimeInterval?

    /// Aanwezig wanneer de huidige bron een genuine, direct verbonden
    /// Jellyfin-server is -- laat `JellyfinServerSkipProvider` dat EXACTE
    /// item bevragen via Jellyfin's Media Segments API (spec §20-22).
    /// Bewust GEEN onderdeel van Hashable/==/de resolved-cache-key hieronder
    /// (net als `duration` hierboven): de gedeelde cache blijft op
    /// canonical media-ID + duration bucket, nooit op stream-/server-item-
    /// ID (spec §33, "niet op stream URL").
    var jellyfinContext: JellyfinSkipSegmentsContext? = nil

    /// Media zonder bruikbare canonical ID heeft geen zin om op te zoeken.
    var isResolvable: Bool { (tmdbID ?? 0) > 0 || (imdbID?.isEmpty == false) }

    /// Duration afgerond op een ruwe bucket van 10s -- voorkomt dat twee
    /// afspeelsessies van dezelfde aflevering met een net iets andere
    /// gemeten duur (bv. 1423.04 vs 1423.09s) als "andere media" in de
    /// cache terechtkomen, terwijl de ruwe `duration` hierboven nog wel
    /// ongewijzigd naar providers gaat (spec §33: "duration bucket indien
    /// relevant" als cache-key, niet als provider-parameter).
    fileprivate var durationBucket: Int? {
        guard let duration, duration.isFinite, duration > 0 else { return nil }
        return Int((duration / 10).rounded())
    }
}

extension VeyraSkipSegment {
    /// Minimale confidence om een segment automatisch over te slaan zonder
    /// tussenkomst van de gebruiker (spec §70: "NOOIT AUTO-SKIP BIJ LAGE
    /// CONFIDENCE"). Een `nil`-confidence (onbekende betrouwbaarheid) is
    /// bewust NIET "goed genoeg" om automatisch te skippen -- de knop blijft
    /// voor zo'n segment wel gewoon beschikbaar (spec: "Knop kan eventueel
    /// nog wel getoond worden"), alleen het automatische deel wordt geblokt.
    static let minimumAutoSkipConfidence: Double = 0.6

    var isEligibleForAutoSkip: Bool {
        guard let confidence else { return false }
        return confidence >= Self.minimumAutoSkipConfidence
    }
}

extension VeyraSkipMediaIdentity: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tmdbID == rhs.tmdbID && lhs.imdbID == rhs.imdbID
            && lhs.season == rhs.season && lhs.episode == rhs.episode
            && lhs.durationBucket == rhs.durationBucket
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(tmdbID)
        hasher.combine(imdbID)
        hasher.combine(season)
        hasher.combine(episode)
        hasher.combine(durationBucket)
    }
}
