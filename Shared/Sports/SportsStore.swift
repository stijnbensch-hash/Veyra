import Foundation
import Combine

@MainActor
protocol SportsScoreProvider {
    func matches(league: SportsLeague, date: Date) async throws -> [SportsMatch]
}

/// Replaceable personal-use adapter. Public ESPN endpoints have no availability guarantee.
@MainActor
struct ESPNScoreProvider: SportsScoreProvider {
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
            var components = URLComponents(string: "\(VeyraEndpoints.sports)/\(league.path)/scoreboard")!
            components.queryItems = [URLQueryItem(name: "dates", value: key), URLQueryItem(name: "limit", value: "1000")]
            if league.id == "college-football" { components.queryItems?.append(URLQueryItem(name: "groups", value: "80")) }
            var request = URLRequest(url: components.url!)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
            matches += try JSONDecoder().decode(ESPNScoreboard.self, from: data).matches(league: league)
        }
        return Dictionary(matches.filter { $0.date >= start && $0.date < end }.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }).values.sorted { $0.date < $1.date }
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
        favorites = Set(defaults.stringArray(forKey: "sports.favoriteTeams") ?? [])
    }

    func toggle(_ team: SportsTeam) {
        if favorites.contains(team.id) { favorites.remove(team.id) } else { favorites.insert(team.id) }
        defaults.set(Array(favorites), forKey: "sports.favoriteTeams")
        SportsFavorites.record(team, isFavorite: favorites.contains(team.id), defaults: defaults)
    }

    /// Herlaadt de favorieten uit UserDefaults (bv. nadat ze in een detailscherm gewijzigd zijn).
    func reloadFavorites() {
        favorites = Set(defaults.stringArray(forKey: "sports.favoriteTeams") ?? [])
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
        favorites = Set(defaults.stringArray(forKey: "sports.favoriteTeams") ?? [])
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
            for league in SportsLeague.all {
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
        matches = next.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
        if failedLeagues.isEmpty { updatedAt = Date() }
    }
}
