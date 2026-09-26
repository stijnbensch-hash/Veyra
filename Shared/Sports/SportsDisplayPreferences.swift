// SportsDisplayPreferences.swift — gedeeld (iOS + tvOS)
// Welke sporten en welke competities daarbinnen getoond worden in het Sport-menu en op de
// Home-sectie "Sport". Bewaard als één JSON-blob in UserDefaults (net als SportsFavorites'
// "sports.favoriteTeamInfo"), zodat VeyraHubSyncService hem als Data-sleutel kan meesyncen.
//
// Standaardgedrag zonder opgeslagen voorkeur: ALLES aan (huidig gedrag, geen filtering),
// zodat bestaande gebruikers geen regressie zien.

import Foundation

nonisolated struct StoredSportsDisplayPreferences: Codable, Hashable, Sendable {
    var enabledCategories: Set<String>
    var enabledLeagueIDs: Set<String>

    static let empty = StoredSportsDisplayPreferences(enabledCategories: [], enabledLeagueIDs: [])
}

enum SportsDisplayPreferences {
    static let key = "sports.displayPreferences"

    /// `nil` betekent: nog geen voorkeur opgeslagen (default = alles aan).
    static func stored(_ defaults: UserDefaults = .standard) -> StoredSportsDisplayPreferences? {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(StoredSportsDisplayPreferences.self, from: data)
        else { return nil }
        return decoded
    }

    private static func save(_ value: StoredSportsDisplayPreferences, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    /// Alle categorieën die momenteel "aan" staan. Zonder opgeslagen voorkeur: alle bestaande categorieën.
    static func enabledCategories(_ defaults: UserDefaults = .standard) -> Set<SportCategory> {
        guard let stored = stored(defaults) else { return Set(SportCategory.allCases) }
        return Set(stored.enabledCategories.compactMap(SportCategory.init(rawValue:)))
    }

    /// Alle competitie-id's die momenteel "aan" staan. Zonder opgeslagen voorkeur: alle bestaande competities.
    static func enabledLeagueIDs(_ defaults: UserDefaults = .standard) -> Set<String> {
        guard let stored = stored(defaults) else { return Set(SportsLeague.all.map(\.id)) }
        return stored.enabledLeagueIDs
    }

    static func isCategoryEnabled(_ category: SportCategory, defaults: UserDefaults = .standard) -> Bool {
        enabledCategories(defaults).contains(category)
    }

    /// Een competitie wordt getoond als zowel haar sport-categorie als de competitie zelf aan staan.
    static func isLeagueEnabled(_ leagueID: String, defaults: UserDefaults = .standard) -> Bool {
        guard let league = SportsLeague.all.first(where: { $0.id == leagueID }) else { return true }
        return isCategoryEnabled(league.sport, defaults: defaults) && enabledLeagueIDs(defaults).contains(leagueID)
    }

    static func setCategory(_ category: SportCategory, enabled: Bool, defaults: UserDefaults = .standard) {
        var categoryIDs = Set(enabledCategories(defaults).map(\.rawValue))
        var leagueIDs = enabledLeagueIDs(defaults)
        if enabled { categoryIDs.insert(category.rawValue) } else { categoryIDs.remove(category.rawValue) }
        // Bij het aanzetten van een sport worden al haar competities standaard mee aangezet
        // (tenzij ze al individueel afgezet waren) — voelt aan als één toggle per sport totdat
        // de gebruiker zelf binnen die sport gaat verfijnen.
        if enabled {
            for league in SportsLeague.all where league.sport == category { leagueIDs.insert(league.id) }
        }
        save(
            StoredSportsDisplayPreferences(enabledCategories: categoryIDs, enabledLeagueIDs: leagueIDs),
            defaults: defaults
        )
    }

    static func setLeague(_ leagueID: String, enabled: Bool, defaults: UserDefaults = .standard) {
        var categoryIDs = Set(enabledCategories(defaults).map(\.rawValue))
        var leagueIDs = enabledLeagueIDs(defaults)
        if enabled { leagueIDs.insert(leagueID) } else { leagueIDs.remove(leagueID) }
        // Eerste keer dat er iets gewijzigd wordt: categorieën expliciet vastleggen zodat de
        // lege-set-betekent-alles-default niet meteen weer alles terugzet.
        if categoryIDs.isEmpty { categoryIDs = Set(SportCategory.allCases.map(\.rawValue)) }
        save(
            StoredSportsDisplayPreferences(enabledCategories: categoryIDs, enabledLeagueIDs: leagueIDs),
            defaults: defaults
        )
    }
}
