import Foundation

/// Fase 3 stap 4 (artwork-engine-spec §38/§39/§40): titelweergave op Detail/Hero/Player-
/// contextbalk/Collection-logokeuze (zie `VeyraClearLogo`). "Automatisch" en "ClearLogo indien
/// beschikbaar" leveren momenteel hetzelfde gedrag (logo tonen als beschikbaar, anders tekst,
/// nooit leeg — §41) omdat Veyra nog geen extra context-afhankelijke auto-heuristiek heeft;
/// beide opties blijven wel apart instelbaar voor latere verfijning.
enum ArtworkTitleDisplayMode: String, CaseIterable, Identifiable, Hashable, Codable {
    case automatic
    case clearLogoIfAvailable
    case alwaysText
    case clearLogoPlusText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatisch"
        case .clearLogoIfAvailable: return "ClearLogo indien beschikbaar"
        case .alwaysText: return "Altijd tekst"
        case .clearLogoPlusText: return "ClearLogo + tekst"
        }
    }
}

/// §52/§53: taalvoorkeur voor de ClearLogo-taalkeuze bij TMDB's `/images` (voorheen hardcoded
/// en inconsistent: `ClearLogoService` deed en→nl, `VeyraTMDBArtwork` deed nl→en).
enum ArtworkLanguageOption: String, CaseIterable, Identifiable, Hashable, Codable {
    case nl
    case en

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nl: return "Nederlands"
        case .en: return "Engels"
        }
    }
}

struct ArtworkSettings: Codable, Equatable {
    var titleDisplay: ArtworkTitleDisplayMode
    var language: ArtworkLanguageOption
    var fallbackLanguage: ArtworkLanguageOption

    static let `default` = ArtworkSettings(titleDisplay: .automatic, language: .nl, fallbackLanguage: .en)
}

struct ArtworkSettingsStore {
    private let defaults: UserDefaults
    private let key = "veyra.artwork.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ArtworkSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ArtworkSettings.self, from: data)
        else { return .default }
        return decoded
    }

    func save(_ settings: ArtworkSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
        NotificationCenter.default.post(name: .artworkSettingsChanged, object: nil)
    }
}

extension Notification.Name {
    static let artworkSettingsChanged = Notification.Name("veyra.artworkSettingsChanged")
}
