// VeyraHeroSpotlightSettings.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Instellingen voor de nieuwe Home-hero bovenaan (trending-carrousel), naar
// het voorbeeld van de Strand-app: stijl (schermvullend/kaart) + twee
// bronnen (TMDB- of Trakt-lijst) die door elkaar gemixt worden getoond.

import Foundation

enum HeroSpotlightStyle: String, Codable, CaseIterable, Hashable {
    case fullscreen
    case card

    var label: String { self == .fullscreen ? "Schermvullend" : "Kaart" }
    var helpText: String {
        self == .fullscreen
            ? "Schermvullend toont de achtergrond van rand tot rand."
            : "Kaart toont een afgeronde carrousel met zichtbare buren."
    }
}

struct HeroSpotlightSettings: Codable, Equatable {
    var style: HeroSpotlightStyle
    var primarySource: ShelfSource
    /// `nil` = alleen de primaire bron; geen secundaire lijst gemixt.
    var secondarySource: ShelfSource?

    static let `default` = HeroSpotlightSettings(
        style: .fullscreen,
        primarySource: .tmdb(list: .trendingDay, kind: .movie),
        secondarySource: .tmdb(list: .trendingDay, kind: .series)
    )
}

struct HeroSpotlightSettingsStore {
    private let defaults: UserDefaults
    private let key = "veyra.home.heroSpotlight.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HeroSpotlightSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(HeroSpotlightSettings.self, from: data)
        else { return .default }
        return decoded
    }

    func save(_ settings: HeroSpotlightSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
        NotificationCenter.default.post(name: .heroSpotlightSettingsChanged, object: nil)
    }
}

extension Notification.Name {
    static let heroSpotlightSettingsChanged = Notification.Name("veyra.heroSpotlightSettingsChanged")
}
