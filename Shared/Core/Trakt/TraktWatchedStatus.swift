import Foundation

enum TraktWatchedTarget {
    case movie(TraktIDs)
    case show(TraktIDs)
    case season(show: TraktIDs, number: Int, episodeCount: Int)
    case episode(show: TraktIDs, season: Int, number: Int)
}

enum TraktWatchedStatus: Equatable {
    case none, watched
    case partial(count: Int, total: Int?)

    static func resolve(_ target: TraktWatchedTarget, movies: [TraktEntry], shows: [TraktEntry], progress: [TraktUpNext]) -> Self {
        let ids: TraktIDs
        switch target {
        case .movie(let movieIDs):
            return movies.contains { $0.movie?.ids.matches(movieIDs) == true && ($0.plays ?? 1) > 0 } ? .watched : .none
        case .show(let showIDs): ids = showIDs
        case .season(let showIDs, _, _), .episode(let showIDs, _, _): ids = showIDs
        }
        let seasons = shows.filter { $0.show?.ids.matches(ids) == true }.flatMap { $0.seasons ?? [] }
        func watchedEpisodes(_ number: Int) -> Set<Int> {
            Set(seasons.filter { $0.number == number }.flatMap(\.episodes)
                .filter { ($0.plays ?? 1) > 0 }.map(\.number))
        }
        switch target {
        case .episode(_, let season, let number):
            return watchedEpisodes(season).contains(number) ? .watched : .none
        case .season(_, let number, let total):
            let count = watchedEpisodes(number).filter { $0 > 0 }.count
            guard count > 0 else { return .none }
            return total > 0 && count >= total ? .watched : .partial(count: count, total: total > 0 ? total : nil)
        case .show:
            // A watched-show record alone means at least one episode, never the whole series.
            if let value = progress.first(where: { $0.show.ids.matches(ids) })?.progress,
               value.aired > 0, value.completed > 0 {
                return value.completed >= value.aired ? .watched : .partial(count: value.completed, total: value.aired)
            }
            let count = Set(seasons.filter { $0.number > 0 }.map(\.number))
                .reduce(0) { $0 + watchedEpisodes($1).filter { $0 > 0 }.count }
            return count > 0 ? .partial(count: count, total: nil) : .none
        case .movie: return .none
        }
    }
}
