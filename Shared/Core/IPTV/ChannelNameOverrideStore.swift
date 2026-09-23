import Foundation

/// Eigen zendernamen ("overrides") per kanaal-ID. Deze staan lokaal in
/// UserDefaults; tussen apparaten gaan ze mee via de gekoppelde VeyraHub-
/// server (`VeyraHubSyncService`, sleutel "veyra.channelNameOverrides" in
/// het "livetv"-document) — er is bewust geen directe iCloud-fallback meer
/// (zie CloudSettingsSync, verwijderd). Belangrijk: `effectiveName(...)`
/// wordt synchroon aangeroepen op elk afspeelmoment van een live-kanaal
/// (`IPTVService.playableSource(for:)`), dus deze klasse mag nooit
/// blokkerend werk (netwerk, iCloud-synchronize) op de main thread doen.
enum ChannelNameOverrideStore {

    private static let localKey =
        "veyra.channelNameOverrides"

    private static let localStore =
        UserDefaults.standard

    // MARK: - Public

    static func name(
        forChannelID channelID: String
    ) -> String? {
        let values =
            localDictionary()

        guard
            let value =
                values[channelID]?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !value.isEmpty
        else {
            return nil
        }

        return value
    }

    static func effectiveName(
        channelID: String,
        defaultName: String
    ) -> String {
        name(
            forChannelID:
                channelID
        )
        ?? defaultName
    }

    static func setName(
        _ name: String?,
        forChannelID channelID: String
    ) {
        var values =
            localDictionary()

        let cleaned =
            name?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        if cleaned.isEmpty {
            values.removeValue(
                forKey:
                    channelID
            )
        } else {
            values[channelID] =
                cleaned
        }

        save(
            values
        )
    }

    static func removeOverride(
        forChannelID channelID: String
    ) {
        setName(
            nil,
            forChannelID:
                channelID
        )
    }

    // Extra aliases zodat bestaande code niet stukgaat
    // als je picker een kortere methodenaam gebruikte.

    static func set(
        _ name: String?,
        forChannelID channelID: String
    ) {
        setName(
            name,
            forChannelID:
                channelID
        )
    }

    static func save(
        name: String?,
        forChannelID channelID: String
    ) {
        setName(
            name,
            forChannelID:
                channelID
        )
    }

    // MARK: - Sync

    /// Ververst schermen die op deze data wachten. VeyraHub's eigen
    /// periodieke sync (zie `VeyraHubSyncService`) haalt en verstuurt de
    /// waarden zelf al op de achtergrond; hier hoeft niets geforceerd te
    /// worden.
    static func synchronize() {
        NotificationCenter
            .default
            .post(
                name:
                    .channelOverrideChanged,
                object:
                    nil
            )
    }

    // MARK: - Storage

    private static func localDictionary()
        -> [String: String]
    {
        localStore
            .dictionary(
                forKey:
                    localKey
            ) as? [String: String]
        ?? [:]
    }

    private static func save(
        _ values: [String: String]
    ) {
        localStore
            .set(
                values,
                forKey:
                    localKey
            )

        NotificationCenter
            .default
            .post(
                name:
                    .channelOverrideChanged,
                object:
                    nil
            )
    }
}
