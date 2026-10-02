// RegionalReleaseSettings.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Instellingen voor "Nieuw van hier" die geen volledige `BentoTile`-zichtbaarheid vereisen (die
// bestaat al -- de hele sectie kan al verborgen worden via `VeyraBentoLayout`/
// `veyraHomeTileMenu(.nieuwVanHier)`). Dit is een granulaire keuze BINNEN de sectie: per
// aanvullende, lagere-confidence bron (vandaag enkel `IPTVVODRegionalReleaseProvider`) apart
// aan/uit, zonder `VRTRegionalReleaseProvider`'s resultaten te raken. Naar het voorbeeld van
// `HeroSpotlightSettings`/`HeroSpotlightSettingsStore`.
import Foundation

struct RegionalReleaseSettings: Codable, Equatable {
    /// Standaard AAN: `IPTVVODRegionalReleaseProvider` meldt zichzelf toch al alleen als de
    /// gebruiker een Xtream-account heeft MET een passende providercategorie (zie dat bestand) --
    /// dit is de uitzetknop voor wie dat wél heeft, maar de (lagere-confidence) IPTV-VOD-signalen
    /// niet naast VRT's eigen "Binnenkort"-releases in "Nieuw van hier" wil zien.
    var showIPTVVODReleases: Bool

    static let `default` = RegionalReleaseSettings(showIPTVVODReleases: true)
}

struct RegionalReleaseSettingsStore {
    private let defaults: UserDefaults
    private let key = "veyra.home.regionalReleases.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> RegionalReleaseSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(RegionalReleaseSettings.self, from: data)
        else { return .default }
        return decoded
    }

    func save(_ settings: RegionalReleaseSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
        NotificationCenter.default.post(name: .regionalReleaseSettingsChanged, object: nil)
    }
}

extension Notification.Name {
    static let regionalReleaseSettingsChanged = Notification.Name("veyra.regionalReleaseSettingsChanged")
}
