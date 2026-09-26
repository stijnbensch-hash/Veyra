// SportsFavorites.swift — gedeeld (iOS + tvOS)
// Favoriete teams: de id's blijven onder "sports.favoriteTeams" staan (zoals SportsStore ze al gebruikt);
// daarnaast worden naam en logo bewaard zodat Instellingen de favorieten kan tonen, en een zoekfunctie
// die alle teams uit de ondersteunde competities via ESPN ophaalt.

import Foundation
import Combine

nonisolated struct StoredFavoriteTeam: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let abbreviation: String
    let logo: String?
}

enum SportsFavorites {
    static let idsKey = "sports.favoriteTeams"
    static let infoKey = "sports.favoriteTeamInfo"

    // Voor deze wijziging gebruikten team-ID's het korte `SportsLeague.id` als voorvoegsel
    // (bv. "nfl:2555", "college-football:52"). Sinds meerdere `SportsLeague`-entries hetzelfde
    // ESPN-pad kunnen delen (de losse college-football-conferences) is het voorvoegsel `SportsLeague.path`
    // geworden (bv. "football/nfl:2555", "football/college-football:52"), zodat wedstrijd- en
    // favorieten-ID's altijd hetzelfde namespace gebruiken. Favorieten die vóór die wijziging bewaard
    // zijn, staan nog in het oude formaat: zonder migratie matchen ze nooit meer met een wedstrijd en
    // blijft de "Favorieten"-rij op Home leeg. Zet ze eenmalig om.
    private static let legacyPrefixMigrationKey = "sports.favoriteTeams.legacyPrefixMigrated"
    private static let legacySoccerPrefixMigrationKey = "sports.favoriteTeams.legacySoccerPrefixMigrated"
    private static let legacyPrefixMap: [String: String] = [
        "bel.1": "soccer",
        "uefa.champions": "soccer",
        "uefa.europa": "soccer",
        "eng.1": "soccer",
        "esp.1": "soccer",
        "ita.1": "soccer",
        "ger.1": "soccer",
        "fra.1": "soccer",
        "nfl": "football/nfl",
        "nba": "basketball/nba",
        "euroleague": "basketball/euroleague",
        "college-football": "football/college-football"
    ]

    private static func migratedID(_ id: String) -> String {
        guard let colon = id.firstIndex(of: ":") else { return id }
        let prefix = String(id[..<colon])
        guard let newPrefix = legacyPrefixMap[prefix] else { return id }
        return newPrefix + id[colon...]
    }

    private static func migrateLegacyPrefixesIfNeeded(_ defaults: UserDefaults) {
        guard !defaults.bool(forKey: legacyPrefixMigrationKey)
                || !defaults.bool(forKey: legacySoccerPrefixMigrationKey) else { return }
        defaults.set(true, forKey: legacyPrefixMigrationKey)
        defaults.set(true, forKey: legacySoccerPrefixMigrationKey)

        let oldIDs = defaults.stringArray(forKey: idsKey) ?? []
        let newIDs = oldIDs.map(migratedID)
        if newIDs != oldIDs { defaults.set(newIDs, forKey: idsKey) }

        if let data = defaults.data(forKey: infoKey),
           let list = try? JSONDecoder().decode([StoredFavoriteTeam].self, from: data) {
            let migrated = list.map {
                StoredFavoriteTeam(id: migratedID($0.id), name: $0.name, abbreviation: $0.abbreviation, logo: $0.logo)
            }
            if migrated.map(\.id) != list.map(\.id), let encoded = try? JSONEncoder().encode(migrated) {
                defaults.set(encoded, forKey: infoKey)
            }
        }
    }

    static func ids(_ defaults: UserDefaults = .standard) -> Set<String> {
        migrateLegacyPrefixesIfNeeded(defaults)
        return Set(defaults.stringArray(forKey: idsKey) ?? [])
    }

    static func info(_ defaults: UserDefaults = .standard) -> [String: StoredFavoriteTeam] {
        migrateLegacyPrefixesIfNeeded(defaults)
        guard let data = defaults.data(forKey: infoKey),
              let list = try? JSONDecoder().decode([StoredFavoriteTeam].self, from: data) else { return [:] }
        return Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Bewaart (of wist) naam en logo van een team, in de pas met de id-lijst.
    static func record(_ team: SportsTeam, isFavorite: Bool, defaults: UserDefaults = .standard) {
        var all = info(defaults)
        if isFavorite {
            all[team.id] = StoredFavoriteTeam(id: team.id, name: team.name, abbreviation: team.abbreviation,
                                              logo: team.logoURL?.absoluteString)
        } else {
            all[team.id] = nil
        }
        if let data = try? JSONEncoder().encode(Array(all.values)) {
            defaults.set(data, forKey: infoKey)
        }
    }

    /// Zet een team aan of uit als favoriet (id-lijst + info).
    static func set(_ team: SportsTeam, favorite: Bool, defaults: UserDefaults = .standard) {
        var current = ids(defaults)
        if favorite { current.insert(team.id) } else { current.remove(team.id) }
        defaults.set(Array(current), forKey: idsKey)
        record(team, isFavorite: favorite, defaults: defaults)
    }

    /// Verwijdert een favoriet enkel op id (ook als er geen info van bekend is).
    static func remove(id: String, defaults: UserDefaults = .standard) {
        var current = ids(defaults)
        current.remove(id)
        defaults.set(Array(current), forKey: idsKey)
        var all = info(defaults)
        all[id] = nil
        if let data = try? JSONEncoder().encode(Array(all.values)) { defaults.set(data, forKey: infoKey) }
    }
}

nonisolated private struct ESPNTeamsResponse: Decodable {
    let sports: [SportNode]?

    struct SportNode: Decodable { let leagues: [LeagueNode]? }
    struct LeagueNode: Decodable { let teams: [Entry]? }
    struct Entry: Decodable { let team: TeamNode }
    struct TeamNode: Decodable {
        let id: String
        let displayName: String
        let abbreviation: String?
        let logos: [LogoNode]?
    }
    struct LogoNode: Decodable { let href: String? }
}

/// Alle teams uit de ondersteunde competities, om in Instellingen in te zoeken.
@MainActor
final class SportsTeamDirectory: ObservableObject {
    @Published private(set) var teams: [SportsTeam] = []
    @Published private(set) var isLoading = false
    @Published private(set) var failed = false
    private var loaded = false

    func load() async {
        guard !loaded, !isLoading else { return }
        isLoading = true
        failed = false
        let base = VeyraEndpoints.sports
        let results = await withTaskGroup(of: [SportsTeam].self) { group in
            for league in SportsLeague.all {
                group.addTask { await Self.fetch(league: league, base: base) }
            }
            var all: [SportsTeam] = []
            for await part in group { all += part }
            return all
        }
        var unique: [String: SportsTeam] = [:]
        for team in results where unique[team.id] == nil { unique[team.id] = team }
        teams = unique.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        failed = teams.isEmpty
        loaded = !teams.isEmpty
        isLoading = false
    }

    func search(_ query: String) -> [SportsTeam] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return teams.filter {
            $0.name.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                || $0.abbreviation.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private nonisolated static func fetch(league: SportsLeague, base: String) async -> [SportsTeam] {
        guard var components = URLComponents(string: "\(base)/\(league.path)/teams") else { return [] }
        components.queryItems = [URLQueryItem(name: "limit", value: "1000")]
        if let groups = league.groups { components.queryItems?.append(URLQueryItem(name: "groups", value: groups)) }
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(ESPNTeamsResponse.self, from: data) else { return [] }

        // Zelfde id-opbouw als de scoreboard-decoder: voetbalclubs delen één id over competities,
        // en meerdere `SportsLeague`-entries die hetzelfde ESPN-pad delen (bv. de losse
        // college-football-conferences) moeten ook hetzelfde team-ID opleveren.
        let sport = league.path.hasPrefix("soccer/") ? "soccer" : league.path
        let entries = (decoded.sports ?? []).flatMap { $0.leagues ?? [] }.flatMap { $0.teams ?? [] }
        return entries.map { entry in
            let t = entry.team
            let abbreviation = t.abbreviation ?? String(t.displayName.prefix(3)).uppercased()
            let logo = t.logos?.compactMap { $0.href }.first.flatMap(URL.init(string:))
                ?? SportsTeam.fallbackLogoURL(abbreviation: abbreviation)
            return SportsTeam(id: "\(sport):\(t.id)", name: t.displayName, abbreviation: abbreviation, logoURL: logo)
        }
    }
}
