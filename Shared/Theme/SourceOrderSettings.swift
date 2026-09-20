import Foundation

/// Categorie- en providervolgorde voor de BRONNEN-groep in Instellingen.
/// Dit leeft bewust in de bestaande BRONNEN-groep zelf (iOS: omhoog/omlaag-
/// knoppen per categoriekaart in `SettingsView`; tvOS: dezelfde knoppen per
/// provider in `IPTVAccountsView`) — geen aparte tweede "Bronnen"-instelling
/// ernaast.
///
/// Status: dit deel is ECHT — de IPTV-providervolgorde bepaalt daadwerkelijk
/// in welke volgorde providers in de IPTV-lijst verschijnen (iOS en tvOS),
/// en de categorievolgorde bepaalt daadwerkelijk in welke volgorde de
/// IPTV/Add-ons/Mediaservers-kaarten in Instellingen → BRONNEN verschijnen.
/// Sorteerregels, filters, resultatenlimiet en broncode-vormgeving zitten
/// hier bewust niet in: de spelerbroncode die dat zou moeten aansturen
/// (`PlayableSource` / `ResolvedSource` / de source-resolver) ontbreekt in
/// deze projectkopie, dus dat wacht tot op de Mac.
enum SourceCategory: String, Codable, CaseIterable, Identifiable, Equatable {
    case mediaServers, iptv, addons

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mediaServers: return "Mediaservers"
        case .iptv: return "IPTV / VOD"
        case .addons: return "Add-ons"
        }
    }

    var symbol: String {
        switch self {
        case .mediaServers: return "server.rack"
        case .iptv: return "tv"
        case .addons: return "puzzlepiece.extension"
        }
    }
}

enum SourceOrderDefaults {
    static let categoryOrderKey = "sourceOrder.categoryOrder"
    static let iptvProviderOrderKey = "sourceOrder.iptvProviderOrder"

    static let defaultCategoryOrder: [SourceCategory] = [.mediaServers, .iptv, .addons]

    // MARK: - Categorievolgorde

    static func loadCategoryOrder(from defaults: UserDefaults = .standard) -> [SourceCategory] {
        guard let data = defaults.data(forKey: categoryOrderKey),
              let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
            return defaultCategoryOrder
        }

        let stored = rawValues.compactMap(SourceCategory.init(rawValue:))
        // Categorieën die (nog) niet in de opgeslagen volgorde zitten (bv. na
        // een appupdate) komen achteraan, in de standaardvolgorde.
        let missing = defaultCategoryOrder.filter { !stored.contains($0) }
        return stored + missing
    }

    static func saveCategoryOrder(_ order: [SourceCategory], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(order.map(\.rawValue)) else { return }
        defaults.set(data, forKey: categoryOrderKey)
    }

    // MARK: - IPTV-providervolgorde

    static func loadIPTVProviderOrder(from defaults: UserDefaults = .standard) -> [UUID] {
        guard let data = defaults.data(forKey: iptvProviderOrderKey),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return strings.compactMap(UUID.init(uuidString:))
    }

    static func saveIPTVProviderOrder(_ order: [UUID], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(order.map(\.uuidString)) else { return }
        defaults.set(data, forKey: iptvProviderOrderKey)
    }

    /// Sorteert providers volgens de opgeslagen volgorde. Providers die nog
    /// niet in de opgeslagen volgorde zitten (nieuw toegevoegd) komen
    /// achteraan, in laadvolgorde.
    static func sortedProviders<T>(_ providers: [T], order: [UUID], id: (T) -> UUID) -> [T] {
        var indexByID: [UUID: Int] = [:]
        for (index, providerID) in order.enumerated() {
            indexByID[providerID] = index
        }

        let indexed = providers.enumerated().map { ($0.offset, $0.element) }
        let sorted = indexed.sorted { lhs, rhs in
            let lhsIndex = indexByID[id(lhs.1)] ?? (order.count + lhs.0)
            let rhsIndex = indexByID[id(rhs.1)] ?? (order.count + rhs.0)
            return lhsIndex < rhsIndex
        }

        return sorted.map(\.1)
    }
}
