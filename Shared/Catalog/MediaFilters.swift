import Foundation

/// Decennium-filter voor Films/Series. Elke optie is een jarenbereik dat
/// bedoeld is om door te geven aan TMDB's discover-endpoint
/// (`primary_release_date.gte`/`.lte` voor films,
/// `first_air_date.gte`/`.lte` voor series) — zie `startYear`/`endYear`.
///
/// NB: `TMDBClient` zelf ontbreekt momenteel in deze export (zie eerdere
/// zip-synchronisatieproblemen), dus deze filter kan nog niet echt tegen
/// TMDB bevragen. Zodra die klasse terug is, breidt `TMDBClient.movies(...)`/
/// `.series(...)` uit met deze twee jaartallen als extra parameters.
struct VeyraDecadeFilter: Identifiable, Hashable {
    let id: String
    let title: String
    let startYear: Int?
    let endYear: Int?

    /// Vaste, aflopende lijst van decennia t/m de huidige. De oudste optie
    /// ("Voor 1970") heeft geen ondergrens.
    static let all: [VeyraDecadeFilter] = {
        let currentDecadeStart = (Calendar.current.component(.year, from: .now) / 10) * 10

        var decades: [VeyraDecadeFilter] = []
        var start = currentDecadeStart

        while start >= 1970 {
            decades.append(
                VeyraDecadeFilter(
                    id: "\(start)s",
                    title: "\(start)'s",
                    startYear: start,
                    endYear: start + 9
                )
            )
            start -= 10
        }

        decades.append(
            VeyraDecadeFilter(id: "pre1970", title: "Voor 1970", startYear: nil, endYear: 1969)
        )

        return decades
    }()
}

/// Minimale-beoordeling-filter, op TMDB's `vote_average`-schaal (0-10).
enum VeyraRatingFilter: Double, CaseIterable, Identifiable {
    case nine = 9
    case eight = 8
    case seven = 7
    case six = 6
    case five = 5

    var id: Double { rawValue }

    var title: String { "\(Int(rawValue))+ ★" }
}

/// Sorteeroptie voor Films/Series, naast de Genre/Decennium/Beoordeling-filters.
/// Anders dan die filters heeft deze altijd een actieve waarde (default `.popular`)
/// — er is bewust geen "geen sortering"-staat.
enum VeyraSortOption: String, CaseIterable, Identifiable {
    case popular
    case trending
    case topRated
    case newest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .popular: return "Populair"
        case .trending: return "Trending"
        case .topRated: return "Top beoordeeld"
        case .newest: return "Nieuw"
        }
    }

    var systemImage: String {
        switch self {
        case .popular: return "flame"
        case .trending: return "chart.line.uptrend.xyaxis"
        case .topRated: return "star.circle"
        case .newest: return "sparkles"
        }
    }
}
