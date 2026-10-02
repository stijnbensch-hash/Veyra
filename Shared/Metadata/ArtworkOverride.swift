import Foundation

/// Fase 3-vervolg (artwork-engine-spec §56-§60): per-titel handmatige artwork-keuze.
enum VeyraArtworkType: String, Codable, CaseIterable, Identifiable {
    case clearLogo
    case poster
    case backdrop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clearLogo: return "ClearLogo"
        case .poster: return "Poster"
        case .backdrop: return "Achtergrond"
        }
    }
}

/// §34/§35: enkel bronnen die Veyra werkelijk meerdere candidates kan laten kiezen -- alleen
/// TMDB's `/images` levert dat vandaag (meerdere talen/afbeeldingen per type). AIOMetadata geeft
/// per titel maar één vast logo/poster/backdrop terug (zie Fase 2 A/B-testrapport §35), dus daar
/// is nog geen keuze mogelijk.
enum VeyraArtworkSource: String, Codable {
    case tmdb
}

/// §60: "geen fragiele URL als enige override" -- canonical identity (via de aanroeper) + type +
/// bron + providerpad/taal; de URL zelf wordt pas bij gebruik via `TMDBImageURLBuilder` herbouwd,
/// nooit zelf opgeslagen als brondata.
struct VeyraArtworkOverride: Codable, Hashable {
    let type: VeyraArtworkType
    let source: VeyraArtworkSource
    let providerPath: String
    let language: String?
}

/// §58/§59: per-titel, blijft geldig totdat de gebruiker zelf opnieuw kiest of "Gebruik
/// automatisch" tikt -- ongeacht wat de automatische resolver (TMDB/AIOMetadata) later als beste
/// zou aanwijzen.
struct VeyraArtworkOverrideStore {
    private let defaults: UserDefaults
    private let key = "veyra.artwork.overrides.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// §56/§60: dezelfde canonical sleutel (tmdbID + film/serie) die Veyra al overal gebruikt,
    /// zodat de override meegaat waar de titel ook opduikt (Home, Hero, Collections, ...), niet
    /// enkel op het scherm waar hij gekozen is.
    static func canonicalKey(tmdbID: Int, kind: ShelfMediaKind) -> String {
        "\(kind.rawValue):\(tmdbID)"
    }

    private func storageKey(canonicalKey: String, type: VeyraArtworkType) -> String {
        "\(canonicalKey)#\(type.rawValue)"
    }

    private func all() -> [String: VeyraArtworkOverride] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: VeyraArtworkOverride].self, from: data)
        else { return [:] }
        return decoded
    }

    private func persist(_ overrides: [String: VeyraArtworkOverride]) {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        defaults.set(data, forKey: key)
        // §66: enkel deze notificatie -- geen volledige metadata-cache wissen, alleen de
        // resolved-artwork-laag (`ArtworkResolver`/`MetadataRepository`) moet dit item opnieuw
        // ophalen.
        NotificationCenter.default.post(name: .artworkOverridesChanged, object: nil)
    }

    func override(canonicalKey: String, type: VeyraArtworkType) -> VeyraArtworkOverride? {
        all()[storageKey(canonicalKey: canonicalKey, type: type)]
    }

    func setOverride(_ override: VeyraArtworkOverride, canonicalKey: String) {
        var overrides = all()
        overrides[storageKey(canonicalKey: canonicalKey, type: override.type)] = override
        persist(overrides)
    }

    /// "Gebruik automatisch" (§57) -- verwijdert de override voor dit type; de normale resolver
    /// (policy/AIOMetadata/TMDB) neemt het weer over.
    func clearOverride(canonicalKey: String, type: VeyraArtworkType) {
        var overrides = all()
        overrides.removeValue(forKey: storageKey(canonicalKey: canonicalKey, type: type))
        persist(overrides)
    }

    func resolvedURL(canonicalKey: String, type: VeyraArtworkType) -> URL? {
        guard let override = override(canonicalKey: canonicalKey, type: type) else { return nil }
        switch type {
        case .clearLogo: return TMDBImageURLBuilder.logo(override.providerPath)
        case .poster: return TMDBImageURLBuilder.poster(override.providerPath)
        case .backdrop: return TMDBImageURLBuilder.backdrop(override.providerPath)
        }
    }
}

extension Notification.Name {
    static let artworkOverridesChanged = Notification.Name("veyra.artworkOverridesChanged")
}
