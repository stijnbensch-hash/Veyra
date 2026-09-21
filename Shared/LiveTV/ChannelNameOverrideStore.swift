import Foundation

/// Door de gebruiker gekozen namen die de standaardnaam van een IPTV-zender
/// (uit de M3U/Xtream-playlist of de EPG) overschrijven.
///
/// Bereikbaar via hetzelfde "Logo aanpassen…"-scherm als
/// `ChannelLogoOverrideStore` (lang indrukken op een zenderlogo in Live TV)
/// — zie `ChannelLogoPickerView.swift` (per platform), dat nu ook een
/// naamveld bevat.
///
/// Opgeslagen als eenvoudige JSON-dictionary in UserDefaults, gesleuteld op
/// `IPTVChannel.id` — hetzelfde patroon als de logo-overschrijvingen.
enum ChannelNameOverrideStore {
    private static let key = "veyra.iptv.channelNameOverrides"

    static func all(from defaults: UserDefaults = .standard) -> [String: String] {
        guard let data = defaults.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    static func name(forChannelID channelID: String, from defaults: UserDefaults = .standard) -> String? {
        all(from: defaults)[channelID]
    }

    /// Effectieve naam voor een zender: de overschrijving indien aanwezig,
    /// anders de standaardnaam die de provider/EPG aanlevert.
    static func effectiveName(
        channelID: String,
        defaultName: String,
        from defaults: UserDefaults = .standard
    ) -> String {
        let override = name(forChannelID: channelID, from: defaults)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let override, !override.isEmpty {
            return override
        }
        return defaultName
    }

    static func setName(_ name: String?, forChannelID channelID: String, in defaults: UserDefaults = .standard) {
        var dict = all(from: defaults)
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            dict[channelID] = trimmed
        } else {
            dict.removeValue(forKey: channelID)
        }
        guard let data = try? JSONEncoder().encode(dict) else { return }
        defaults.set(data, forKey: key)
    }

    static func removeOverride(forChannelID channelID: String, in defaults: UserDefaults = .standard) {
        setName(nil, forChannelID: channelID, in: defaults)
    }
}
