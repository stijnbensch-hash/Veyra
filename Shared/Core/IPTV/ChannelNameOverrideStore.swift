import Foundation

enum ChannelNameOverrideStore {

    private static let localKey =
        "veyra.channelNameOverrides"

    private static let cloudKey =
        "veyra.channelNameOverrides.v1"

    private static let localStore =
        UserDefaults.standard

    private static let cloudStore =
        NSUbiquitousKeyValueStore.default

    private static var hasStartedSync =
        false

    private static var observer:
        NSObjectProtocol?

    // MARK: - Public

    static func name(
        forChannelID channelID: String
    ) -> String? {
        startSyncIfNeeded()

        let values =
            currentOverrides()

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
        startSyncIfNeeded()

        var values =
            currentOverrides()

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

    static func synchronize() {
        startSyncIfNeeded()

        cloudStore
            .synchronize()

        mergeCloudIntoLocal()

        NotificationCenter
            .default
            .post(
                name:
                    .channelOverrideChanged,
                object:
                    nil
            )
    }

    // MARK: - Startup

    private static func startSyncIfNeeded() {
        guard
            !hasStartedSync
        else {
            return
        }

        hasStartedSync =
            true

        cloudStore
            .synchronize()

        migrateOrMerge()

        observer =
            NotificationCenter
                .default
                .addObserver(
                    forName:
                        NSUbiquitousKeyValueStore
                            .didChangeExternallyNotification,
                    object:
                        cloudStore,
                    queue:
                        .main
                ) { _ in
                    mergeCloudIntoLocal()

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

    // MARK: - Storage

    private static func currentOverrides()
        -> [String: String]
    {
        startSyncIfNeeded()

        if let cloud =
            cloudDictionary()
        {
            localStore
                .set(
                    cloud,
                    forKey:
                        localKey
                )

            return cloud
        }

        return localDictionary()
    }

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

    private static func cloudDictionary()
        -> [String: String]?
    {
        guard
            cloudStore
                .object(
                    forKey:
                        cloudKey
                )
            != nil
        else {
            return nil
        }

        return cloudStore
            .dictionary(
                forKey:
                    cloudKey
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

        cloudStore
            .set(
                values,
                forKey:
                    cloudKey
            )

        cloudStore
            .synchronize()

        NotificationCenter
            .default
            .post(
                name:
                    .channelOverrideChanged,
                object:
                    nil
            )
    }

    // MARK: - Migration

    private static func migrateOrMerge() {
        let local =
            localDictionary()

        if let cloud =
            cloudDictionary()
        {
            var merged =
                cloud

            // Lokale waarden die nog niet in iCloud bestaan bewaren.
            for (
                channelID,
                name
            ) in local
            where merged[channelID]
                == nil
            {
                merged[channelID] =
                    name
            }

            saveWithoutNotification(
                merged
            )

        } else if !local.isEmpty {
            cloudStore
                .set(
                    local,
                    forKey:
                        cloudKey
                )

            cloudStore
                .synchronize()
        }
    }

    private static func mergeCloudIntoLocal() {
        guard
            let cloud =
                cloudDictionary()
        else {
            return
        }

        localStore
            .set(
                cloud,
                forKey:
                    localKey
            )
    }

    private static func saveWithoutNotification(
        _ values: [String: String]
    ) {
        localStore
            .set(
                values,
                forKey:
                    localKey
            )

        cloudStore
            .set(
                values,
                forKey:
                    cloudKey
            )

        cloudStore
            .synchronize()
    }
}
