import Foundation

/// Bron voor algemene metadata (poster/achtergrond/overzicht) van items die
/// zelf geen afbeeldingen meeleveren, zoals een Trakt-lijst. TMDB is de
/// standaard; een AIOMetadata-addon kan hiervoor in de plaats komen.
enum MetadataSourceOption: String, Codable, CaseIterable, Identifiable {
    case tmdb
    case aioMetadataAddon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tmdb: return "TMDB"
        case .aioMetadataAddon: return "AIOMetadata-addon"
        }
    }

    var subtitle: String {
        switch self {
        case .tmdb: return "Standaard, geen addon nodig"
        case .aioMetadataAddon: return "Metadata-addon ingesteld via VeyraHub"
        }
    }
}

enum MetadataSourcePreference {
    private static let storageKey = "metadata.source.preference"

    static var current: MetadataSourceOption {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let option = MetadataSourceOption(rawValue: raw)
        else { return .tmdb }
        return option
    }

    static func set(_ option: MetadataSourceOption) {
        UserDefaults.standard.set(option.rawValue, forKey: storageKey)
    }

    /// De actief ingeschakelde AIOMetadata-addon, indien de voorkeur daarop
    /// staat én er eentje in de gesynchroniseerde configuratie staat.
    static func activeAddon() -> AddonManifest? {
        guard current == .aioMetadataAddon else { return nil }
        return AddonStore().enabledAddons().first { $0.kind == .aioMetadata }
    }
}
