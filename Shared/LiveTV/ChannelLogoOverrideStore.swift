import Foundation

/// Door de gebruiker gekozen logo's die het standaardlogo van een IPTV-
/// zender (uit de M3U/Xtream-playlist of de EPG) overschrijven.
///
/// Bereikbaar door lang in te drukken op een zenderlogo in Live TV (zowel
/// in de zenderlijst als op tvOS in het zenderbeheerscherm) — zie
/// `ChannelLogoPickerView.swift` (per platform) voor de UI. Daar kan
/// gekozen worden uit de iptv-org logo-database (`IPTVOrgLogoDirectory`),
/// een eigen URL, of (op iOS) een foto uit de fotobibliotheek.
///
/// Opgeslagen als eenvoudige JSON-dictionary in UserDefaults, gesleuteld op
/// `IPTVChannel.id` — die al "m3u-…" of "xtream-live-…" bevat, dus uniek
/// genoeg over providers heen zonder aparte scoping.
enum ChannelLogoOverrideStore {
    static let key = "veyra.iptv.channelLogoOverrides"

    static func all(from defaults: UserDefaults = .standard) -> [String: String] {
        guard let data = defaults.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    static func logoURL(forChannelID channelID: String, from defaults: UserDefaults = .standard) -> URL? {
        all(from: defaults)[channelID].flatMap(URL.init(string:))
    }

    /// Effectief logo voor een zender: de overschrijving indien aanwezig,
    /// anders het standaardlogo dat de provider/EPG aanlevert.
    static func effectiveLogoURL(
        channelID: String,
        defaultLogoURL: URL?,
        from defaults: UserDefaults = .standard
    ) -> URL? {
        logoURL(forChannelID: channelID, from: defaults) ?? defaultLogoURL
    }

    static func setLogoURL(_ url: URL?, forChannelID channelID: String, in defaults: UserDefaults = .standard) {
        var dict = all(from: defaults)
        if let url {
            dict[channelID] = url.absoluteString
        } else {
            dict.removeValue(forKey: channelID)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(dict) else { return }
        defaults.set(data, forKey: key)
        NotificationCenter.default.post(name: .channelOverrideChanged, object: nil)
    }

    static func removeOverride(forChannelID channelID: String, in defaults: UserDefaults = .standard) {
        setLogoURL(nil, forChannelID: channelID, in: defaults)
    }

    /// Map van gekozen lokale afbeeldingen (uit de fotobibliotheek, iOS) op
    /// schijf, zodat de override-URL na een herstart nog geldig is. Bestanden
    /// leven in de app-container en worden niet automatisch opgeruimd als de
    /// override later wordt teruggezet — dat is aanvaardbaar voor een paar
    /// kleine logo-afbeeldingen.
    static func localLogoDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("ChannelLogos", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func saveLocalLogo(_ data: Data, forChannelID channelID: String) -> URL? {
        let safeName = channelID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        let fileURL = localLogoDirectory().appendingPathComponent("\(safeName).png")
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }
}

/// Gepost telkens een logo- of naam-overschrijving verandert (zie
/// `ChannelLogoOverrideStore` hierboven en `ChannelNameOverrideStore`).
/// Schermen die een zendernaam of -logo tonen luisteren hierop om
/// zichzelf te verversen, ook wanneer de wijziging op een ander scherm
/// gebeurde en dit scherm intussen al in het geheugen zat (bv. de
/// Home-tab op de achtergrond) — zonder deze melding zou zo'n scherm pas
/// bijwerken bij een volledig nieuwe weergave.
extension Notification.Name {
    static let channelOverrideChanged = Notification.Name("veyra.iptv.channelOverrideChanged")
}
