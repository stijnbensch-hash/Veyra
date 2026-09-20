import Foundation

/// Hero-instellingen voor de featured banner bovenaan Home: vormgeving
/// (kaart/schermvullend) plus een primaire en secundaire bron. Op
/// expliciet verzoek beperkt tot TMDB (geen Trakt/addon), in lijn met hoe
/// de bestaande "Planken"-TMDB-bronnen al werken — zie `TMDBShelfList` in
/// `Shelf.swift`.
enum HeroStyle: String, Codable, CaseIterable, Identifiable {
    case card
    case fullScreen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .card: return "Kaart"
        case .fullScreen: return "Schermvullend"
        }
    }

    var description: String {
        switch self {
        case .card:
            return "Kaart toont een afgeronde carrousel met zichtbare buren."
        case .fullScreen:
            return "Schermvullend toont de achtergrond van rand tot rand."
        }
    }
}

/// Eén TMDB-bron voor de hero: een mediasoort (films/series) plus een
/// standaardlijst (`TMDBShelfList`), net als bij Planken.
struct HeroSourceSelection: Codable, Equatable, Hashable {
    var kind: ShelfMediaKind
    var list: TMDBShelfList

    var label: String { list.label(for: kind) }

    static let defaultPrimary = HeroSourceSelection(kind: .movie, list: .trendingWeek)
    static let defaultSecondary = HeroSourceSelection(kind: .series, list: .trendingWeek)
}

enum HeroSettingsDefaults {
    static let styleKey = "veyra.hero.style"
    static let primarySourceKey = "veyra.hero.primarySource"
    static let secondarySourceKey = "veyra.hero.secondarySource"
}

/// Laadt/bewaart de hero-instellingen in `UserDefaults`, op dezelfde manier
/// als de rest van Veyra (JSON voor de samengestelde bronwaarde — zie ook
/// `SourceOrderDefaults`/`IPTVProviderPreferences`).
enum HeroSettingsStore {
    static func loadStyle(from defaults: UserDefaults = .standard) -> HeroStyle {
        guard let raw = defaults.string(forKey: HeroSettingsDefaults.styleKey) else { return .fullScreen }
        return HeroStyle(rawValue: raw) ?? .fullScreen
    }

    static func saveStyle(_ style: HeroStyle, to defaults: UserDefaults = .standard) {
        defaults.set(style.rawValue, forKey: HeroSettingsDefaults.styleKey)
    }

    static func loadPrimarySource(from defaults: UserDefaults = .standard) -> HeroSourceSelection {
        load(key: HeroSettingsDefaults.primarySourceKey, default: .defaultPrimary, from: defaults)
    }

    static func savePrimarySource(_ selection: HeroSourceSelection, to defaults: UserDefaults = .standard) {
        save(selection, key: HeroSettingsDefaults.primarySourceKey, to: defaults)
    }

    static func loadSecondarySource(from defaults: UserDefaults = .standard) -> HeroSourceSelection {
        load(key: HeroSettingsDefaults.secondarySourceKey, default: .defaultSecondary, from: defaults)
    }

    static func saveSecondarySource(_ selection: HeroSourceSelection, to defaults: UserDefaults = .standard) {
        save(selection, key: HeroSettingsDefaults.secondarySourceKey, to: defaults)
    }

    private static func load(
        key: String,
        default defaultValue: HeroSourceSelection,
        from defaults: UserDefaults
    ) -> HeroSourceSelection {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(HeroSourceSelection.self, from: data)
        else {
            return defaultValue
        }

        return decoded
    }

    private static func save(_ selection: HeroSourceSelection, key: String, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: key)
    }
}
