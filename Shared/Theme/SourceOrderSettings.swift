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

    // MARK: - Bronvolgorde (addons/mediaservers in "Selecteer bron")

    /// Volgorde van addon-/mediaservernamen zoals ze in "Selecteer bron"
    /// (SourceSelectionView, iOS én tvOS) verschijnen — zowel bij "Alle" als
    /// bij de losse filterknoppen. Onder Instellingen → Bronnen →
    /// Bronverschijning → Bronvolgorde in te stellen. Losstaand van
    /// `categoryOrder`/`iptvProviderOrder` hierboven: die twee gaan over
    /// Instellingen zelf, dit gaat over de speler-broncode.
    static let originOrderKey = "sourceOrder.originOrder"

    static func loadOriginOrder(from defaults: UserDefaults = .standard) -> [String] {
        guard let data = defaults.data(forKey: originOrderKey),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return strings
    }

    static func saveOriginOrder(_ order: [String], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(order) else { return }
        defaults.set(data, forKey: originOrderKey)
    }

    /// Sorteert waarden op hun origin-naam volgens de opgeslagen volgorde
    /// (hoofdletterongevoelig). Namen die niet in de opgeslagen volgorde
    /// voorkomen (nieuwe addon, nog niet ingesteld) behouden hun relatieve
    /// plek, achteraan.
    ///
    /// `isFromHub` markeert bronnen die via een VeyraHub-server komen. Voor
    /// die bronnen is VeyraHub's eigen addonvolgorde (in te stellen op de
    /// hub zelf) leidend — de API levert streams al in die volgorde aan.
    /// Deze functie past de lokale Bronvolgorde-lijst daarom NOOIT toe op
    /// hub-bronnen, ook niet als een addonnaam toevallig ook in de lokale
    /// lijst voorkomt (bv. een stale/verouderde entry): ze behouden altijd
    /// hun binnenkomende (hub-gerangschikte) relatieve volgorde. Zo hoeft
    /// een VeyraHub-addon niet apart in Instellingen → Bronvolgorde gezet
    /// te worden, en kan de volgorde nooit uit sync raken met de hub.
    static func sortedByOriginOrder<T>(
        _ values: [T],
        order: [String],
        originName: (T) -> String,
        isFromHub: (T) -> Bool = { _ in false }
    ) -> [T] {
        guard !order.isEmpty else { return values }

        var rank: [String: Int] = [:]
        for (index, name) in order.enumerated() {
            rank[name.lowercased()] = index
        }

        let indexed = values.enumerated().map { ($0.offset, $0.element) }
        let sorted = indexed.sorted { lhs, rhs in
            let lhsRank = isFromHub(lhs.1) ? (order.count + lhs.0) : (rank[originName(lhs.1).lowercased()] ?? (order.count + lhs.0))
            let rhsRank = isFromHub(rhs.1) ? (order.count + rhs.0) : (rank[originName(rhs.1).lowercased()] ?? (order.count + rhs.0))
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.0 < rhs.0
        }

        return sorted.map(\.1)
    }
}
