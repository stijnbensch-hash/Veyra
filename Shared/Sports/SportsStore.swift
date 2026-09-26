import Foundation
import Combine

@MainActor
protocol SportsScoreProvider {
    func matches(league: SportsLeague, date: Date) async throws -> [SportsMatch]
}

/// Replaceable personal-use adapter. Public ESPN endpoints have no availability guarantee.
@MainActor
struct ESPNScoreProvider: SportsScoreProvider {
    /// De Home-sectie vraagt een ruimer venster op. ESPN accepteert jaar- en
    /// maandwaarden voor `dates`, maar geen bereik met twee volledige datums.
    func matches(league: SportsLeague, from: Date, to: Date) async throws -> [SportsMatch] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyyMM"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = formatter.timeZone
        var month = calendar.date(from: calendar.dateComponents([.year, .month], from: from))!
        let lastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: to))!
        var matches: [SportsMatch] = []
        var succeeded = false
        while month <= lastMonth {
            try Task.checkCancellation()
            if let part = try? await fetch(league: league, dates: formatter.string(from: month)) {
                matches += part
                succeeded = true
            }
            month = calendar.date(byAdding: .month, value: 1, to: month)!
        }
        guard succeeded else { throw URLError(.badServerResponse) }
        return Dictionary(matches.filter { $0.date >= from && $0.date < to }.map { ($0.id, $0) },
                          uniquingKeysWith: { a, _ in a }).values.sorted { $0.date < $1.date }
    }

    func matches(league: SportsLeague, date: Date) async throws -> [SportsMatch] {
        // ESPN groups scoreboards by US Eastern days. Query the days that overlap
        // the user's local day, then filter in the user's time zone.
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyyMMdd"
        let keys = Set([formatter.string(from: start), formatter.string(from: end.addingTimeInterval(-1))])
        var matches: [SportsMatch] = []
        for key in keys.sorted() {
            try Task.checkCancellation()
            matches += try await fetch(league: league, dates: key)
        }
        return Dictionary(matches.filter { $0.date >= start && $0.date < end }.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }).values.sorted { $0.date < $1.date }
    }

    private func fetch(league: SportsLeague, dates: String) async throws -> [SportsMatch] {
        var components = URLComponents(string: "\(VeyraEndpoints.sports)/\(league.path)/scoreboard")!
        components.queryItems = [URLQueryItem(name: "dates", value: dates), URLQueryItem(name: "limit", value: "1000")]
        if let groups = league.groups { components.queryItems?.append(URLQueryItem(name: "groups", value: groups)) }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(ESPNScoreboard.self, from: data).matches(league: league)
    }
}

@MainActor
final class SportsStore: ObservableObject {
    @Published private(set) var matches: [SportsMatch] = []
    @Published private(set) var isLoading = false
    @Published private(set) var failedLeagues: [String] = []
    @Published private(set) var updatedAt: Date?
    @Published private(set) var selectedDate = Calendar.current.startOfDay(for: Date())
    @Published private(set) var favorites: Set<String>
    private let provider: any SportsScoreProvider
    private let defaults: UserDefaults
    private var generation = UUID()

    init(provider: (any SportsScoreProvider)? = nil, defaults: UserDefaults = .standard) {
        self.provider = provider ?? ESPNScoreProvider()
        self.defaults = defaults
        favorites = SportsFavorites.ids(defaults)
    }

    func toggle(_ team: SportsTeam) {
        if favorites.contains(team.id) { favorites.remove(team.id) } else { favorites.insert(team.id) }
        defaults.set(Array(favorites), forKey: "sports.favoriteTeams")
        SportsFavorites.record(team, isFavorite: favorites.contains(team.id), defaults: defaults)
    }

    /// Herlaadt de favorieten uit UserDefaults (bv. nadat ze in een detailscherm gewijzigd zijn).
    func reloadFavorites() {
        favorites = SportsFavorites.ids(defaults)
    }

    func isFavorite(_ match: SportsMatch) -> Bool { favorites.contains(match.home.id) || favorites.contains(match.away.id) }

    func isFavoriteTeam(_ team: SportsTeam) -> Bool { favorites.contains(team.id) }

    var highlights: [SportsMatch] {
        Array(matches.sorted { a, b in
            @MainActor func rank(_ m: SportsMatch) -> Int { (m.phase == .live ? 0 : m.phase == .scheduled ? 2 : 4) + (isFavorite(m) ? 0 : 1) }
            return rank(a) == rank(b) ? a.date < b.date : rank(a) < rank(b)
        }.prefix(12))
    }

    func refresh(date: Date, force: Bool = false) async {
        favorites = SportsFavorites.ids(defaults)
        let day = Calendar.current.startOfDay(for: date)
        let dateChanged = day != selectedDate
        if !dateChanged && isLoading { return }
        if !force && !dateChanged, let updatedAt, Date().timeIntervalSince(updatedAt) < 55 { return }
        let ticket = UUID()
        generation = ticket
        if dateChanged { matches = []; updatedAt = nil; failedLeagues = [] }
        selectedDate = day
        isLoading = true
        let results = await withTaskGroup(of: (String, [SportsMatch]?).self) { group in
            for league in SportsLeague.all where SportsDisplayPreferences.isLeagueEnabled(league.id, defaults: defaults) {
                group.addTask { @MainActor [provider] in
                    do { return (league.id, try await provider.matches(league: league, date: day)) }
                    catch { return (league.id, nil) }
                }
            }
            var results: [(String, [SportsMatch]?)] = []
            for await result in group { results.append(result) }
            return results
        }
        guard generation == ticket else { return }
        isLoading = false
        guard !Task.isCancelled else { return }
        // A failed league keeps its previous values, visibly marked stale in the UI.
        var next = matches
        failedLeagues = []
        for (league, events) in results {
            if let events { next.removeAll { $0.league.id == league }; next += events }
            else { failedLeagues.append(league) }
        }
        // Competities die intussen uitgezet zijn in de sportvoorkeuren: ook meteen weg,
        // anders blijven hun oude wedstrijden zichtbaar tot de volgende dagwissel.
        next.removeAll { !SportsDisplayPreferences.isLeagueEnabled($0.league.id, defaults: defaults) }
        matches = next.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
        if failedLeagues.isEmpty { updatedAt = Date() }
    }
}
