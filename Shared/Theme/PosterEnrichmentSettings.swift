import Foundation

/// "Posterverrijking" — badges (genre, beoordeling, leeftijdsclassificatie,
/// kwaliteitslabels, trendlabels) bovenop de posterafbeelding zelf, zoals
/// Strand dat aanbiedt onder Metadata.
///
/// Elk platform (iOS en tvOS zijn aparte apps met een eigen `UserDefaults`)
/// bewaart zijn eigen keuze via deze zelfde sleutels, zodat de instelling
/// per toestel werkt zoals de rest van Veyra dat al doet (bv. Trakt-koppeling).
///
/// Vier van de vijf badges zijn functioneel (via `PosterEnrichmentDataStore`):
/// Genre en Beoordeling komen uit data die Veyra al ophaalt voor de poster
/// zelf; Leeftijdsclassificatie en Trendlabels komen rechtstreeks van TMDB
/// (release_dates/content_ratings, trending/day — met een korte cache).
/// ("Resterende afleveringen" bestaat hier niet meer als apart badge-type --
/// dat toont het "bekeken"-vinkje nu zelf via Trakt, zie `VeyraWatchedCheckmark`.)
/// Kwaliteitslabels (bv. "4K"/"HDR") is de uitzondering: die info bestaat
/// pas nadat een stream voor een titel is opgezocht (bron-resolutie), wat
/// voor een heel postersrooster onbetaalbaar veel netwerkverkeer zou zijn
/// — die toggle blijft daarom uitgeschakeld met uitleg in de UI.
enum PosterEnrichmentMode: String, CaseIterable, Identifiable {
    case off
    case betterPosters

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Uit"
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
