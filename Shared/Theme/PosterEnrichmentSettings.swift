import Foundation

/// "Posterverrijking" — badges (genre, beoordeling, leeftijdsclassificatie,
/// kwaliteitslabels, trendlabels, resterende afleveringen) bovenop de
/// posterafbeelding zelf, zoals Strand dat aanbiedt onder Metadata.
///
/// Elk platform (iOS en tvOS zijn aparte apps met een eigen `UserDefaults`)
/// bewaart zijn eigen keuze via deze zelfde sleutels, zodat de instelling
/// per toestel werkt zoals de rest van Veyra dat al doet (bv. Trakt-koppeling).
///
/// Status: de UI en de "Better Posters"-weergave (genre + beoordeling,
/// lokaal samengesteld uit data die Veyra al ophaalt) zijn functioneel.
/// "RPDB" is hier alleen als keuze aanwezig — een echte RatingPosterDB-
/// integratie (API-sleutel, aanroepen, beeld ophalen) is nog niet gebouwd.
/// Leeftijdsclassificatie, kwaliteitslabels, trendlabels en "resterende
/// afleveringen" tonen momenteel niets: Veyra haalt die gegevens nog niet
/// op. De toggles bestaan alvast zodat de instelling meteen klaarstaat
/// zodra die databronnen worden toegevoegd.
enum PosterEnrichmentMode: String, CaseIterable, Identifiable {
    case off
    case rpdb
    case betterPosters

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Uit"
        case .rpdb: return "RPDB"
        case .betterPosters: return "Better Posters"
        }
    }
}

/// Beoordelingsbron voor de posterbadge. Los van de meerkeuze-toggles op
/// het bestaande "Metadata"-scherm (die gaan over de detailpagina) — hier
/// kies je één bron voor op de poster zelf, net als in Strand.
enum PosterRatingSource: String, CaseIterable, Identifiable {
    case imdb
    case tmdb
    case tomatometer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .imdb: return "IMDb"
        case .tmdb: return "TMDB"
        case .tomatometer: return "Rotten Tomatoes"
        }
    }
}

enum PosterEnrichmentDefaults {
    static let modeKey = "posterEnrichment.mode"
    static let showGenreKey = "posterEnrichment.showGenre"
    static let showRatingKey = "posterEnrichment.showRating"
    static let ratingSourceKey = "posterEnrichment.ratingSource"
    static let showAgeRatingKey = "posterEnrichment.showAgeRating"
    static let showQualityLabelsKey = "posterEnrichment.showQualityLabels"
    static let showTrendLabelsKey = "posterEnrichment.showTrendLabels"
    static let showEpisodesRemainingKey = "posterEnrichment.showEpisodesRemaining"
}

/// TMDB's eigen, publieke genre-ID's — vertaald voor de Nederlandse
/// interface. Vaste lijst rechtstreeks van TMDB, geen verzonnen data.
enum TMDBGenreNames {
    static let movie: [Int: String] = [
        28: "Actie", 12: "Avontuur", 16: "Animatie", 35: "Komedie",
        80: "Misdaad", 99: "Documentaire", 18: "Drama", 10751: "Familie",
        14: "Fantasy", 36: "Geschiedenis", 27: "Horror", 10402: "Muziek",
        9648: "Mysterie", 10749: "Romantiek", 878: "Sciencefiction",
        10770: "TV-film", 53: "Thriller", 10752: "Oorlog", 37: "Western",
    ]

    static let tv: [Int: String] = [
        10759: "Actie en avontuur", 16: "Animatie", 35: "Komedie", 80: "Misdaad",
        99: "Documentaire", 18: "Drama", 10751: "Familie", 10762: "Kids",
        9648: "Mysterie", 10763: "Nieuws", 10764: "Reality",
        10765: "Sciencefiction en fantasy", 10766: "Soap", 10767: "Talk",
        10768: "Oorlog en politiek", 37: "Western",
    ]

    static func movieName(for id: Int) -> String? { movie[id] }
    static func tvName(for id: Int) -> String? { tv[id] }

    /// Eerste herkende genre uit een lijst TMDB genre-ID's, voor gebruik
    /// op een posterbadge (die toont maar één genre, zoals in Strand).
    static func firstMovieName(for ids: [Int]) -> String? {
        ids.compactMap { movie[$0] }.first
    }

    static func firstTVName(for ids: [Int]) -> String? {
        ids.compactMap { tv[$0] }.first
    }
}
