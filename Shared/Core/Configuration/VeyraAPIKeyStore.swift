import Foundation
import Security

enum VeyraAPIKey: String, CaseIterable {
    case tmdbReadAccessToken
    case openSubtitlesAPIKey
    case traktClientID
    case traktClientSecret
    case omdbAPIKey
    case fanartAPIKey

    var account: String {
        switch self {
        case .tmdbReadAccessToken:
            return "tmdb.read-access-token"

        case .openSubtitlesAPIKey:
            return "opensubtitles.api-key"

        case .traktClientID:
            return "trakt.client-id"

        case .traktClientSecret:
            return "trakt.client-secret"

        case .omdbAPIKey:
            return "omdb.api-key"

        case .fanartAPIKey:
            return "fanart.api-key"
        }
    }
}

extension Notification.Name {
    /// Gepost telkens een API-sleutel (Trakt, TMDB, OMDb, ...) lokaal
    /// wordt gewijzigd, zodat `VeyraHubSyncService` dat meteen naar de
    /// andere apparaten kan doorsturen.
    static let veyraAPIKeysDidChange = Notification.Name("veyra.apiKeys.didChange")
}

enum VeyraAPIKeyStore {
    /// Vast, niet van de bundle-ID afhankelijk service-label, zodat zowel
    /// de app (`com.veyra.Veyra`) als de VeyraTopShelf-extensie
    /// (`com.veyra.Veyra.VeyraTopShelf`) dezelfde keychain-items zien —
    /// nodig zodat de extensie de Trakt/TMDB-sleutels kan lezen om
    /// "Verder kijken" te tonen zonder dat de app open staat.
    private static let service = "com.veyra.shared.apikeys"

    /// Het vroegere, per-target service-label (`Bundle.main.bundleIdentifier`).
    /// Uitsluitend nog gebruikt om bestaande sleutels van vóór deze wijziging
    /// één keer over te zetten naar `service`, zodat niemand hun al
    /// ingevulde Trakt/TMDB-sleutels kwijtraakt.
    private static var legacyService: String? {
        Bundle.main.bundleIdentifier
    }

    private static var accessGroup: String? {
        VeyraKeychainAccessGroup.shared
    }

    // MARK: - Hub sync
    //
    // De sleutels staan lokaal in de keychain (nooit in UserDefaults/iCloud),
    // maar gaan via VeyraHub's "settings"-document mee tussen apparaten —
    // zelfde aanpak als de IPTV-providergegevens in `IPTVConfigurationStore`.

    static func exportForHub() -> [String: String] {
        var values: [String: String] = [:]
        for key in VeyraAPIKey.allCases {
            if let value = value(for: key) {
                values[key.rawValue] = value
            }
        }
        return values
    }

    /// Past inkomende Hub-waarden lokaal toe. Een lege/ontbrekende
    /// waarde op de Hub wist hier nooit een al ingevulde sleutel —
    /// zo kan een apparaat dat een sleutel nog niet kent nooit een
    /// werkende sleutel op een ander apparaat overschrijven met niets.
    static func importFromHub(_ values: [String: String]) {
        for key in VeyraAPIKey.allCases {
            guard let incoming = values[key.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !incoming.isEmpty,
                  incoming != value(for: key)
            else { continue }

            try? set(incoming, for: key)
        }
    }

    private static func readRaw(service: String, account: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let accessGroup, service == self.service {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard
            status == errSecSuccess,
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func value(
        for key: VeyraAPIKey
    ) -> String? {
        if let value = readRaw(service: service, account: key.account) {
            return value
        }

        // Val terug op het oude, bundle-ID-afhankelijke item en zet het
        // meteen om naar het nieuwe gedeelde item, zodat een al
        // ingevulde sleutel niet verdwijnt door deze wijziging en de
        // migratie maar één keer per sleutel hoeft te gebeuren.
        guard
            let legacyService,
            legacyService != service,
            let legacyValue = readRaw(service: legacyService, account: key.account)
        else {
            return nil
        }

        try? set(legacyValue, for: key)
        return legacyValue
    }

    static func set(
        _ value: String?,
        for key: VeyraAPIKey
    ) throws {
        let trimmed =
            value?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            ?? ""

        if trimmed.isEmpty {
            try remove(key)
            return
        }

        guard
            let data = trimmed.data(
                using: .utf8
            )
        else {
            throw VeyraAPIKeyStoreError.encoding
        }

        var baseQuery: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                key.account
        ]
        if let accessGroup {
            baseQuery[kSecAttrAccessGroup as String] = accessGroup
        }

        let update: [String: Any] = [
            kSecValueData as String:
                data,

            kSecAttrAccessible as String:
                kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus =
            SecItemUpdate(
                baseQuery as CFDictionary,
                update as CFDictionary
            )

        if updateStatus == errSecSuccess {
            NotificationCenter.default.post(name: .veyraAPIKeysDidChange, object: nil)
            return
        }

        guard
            updateStatus == errSecItemNotFound
        else {
            throw VeyraAPIKeyStoreError.keychain(
                updateStatus
            )
        }

        var insert =
            baseQuery

        insert[kSecValueData as String] =
            data

        insert[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlock

        let addStatus =
            SecItemAdd(
                insert as CFDictionary,
                nil
            )

        guard
            addStatus == errSecSuccess
        else {
            throw VeyraAPIKeyStoreError.keychain(
                addStatus
            )
        }

        NotificationCenter.default.post(name: .veyraAPIKeysDidChange, object: nil)
    }

    static func remove(
        _ key: VeyraAPIKey
    ) throws {
        var query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                key.account
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status =
            SecItemDelete(
                query as CFDictionary
            )

        if status == errSecSuccess {
            NotificationCenter.default.post(name: .veyraAPIKeysDidChange, object: nil)
        }

        guard
            status == errSecSuccess
            || status == errSecItemNotFound
        else {
            throw VeyraAPIKeyStoreError.keychain(
                status
            )
        }
    }
}

enum VeyraAPIKeyStoreError:
    LocalizedError
{
    case encoding
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encoding:
            return "De API-sleutel kon niet worden opgeslagen."

        case .keychain(let status):
            if let message =
                SecCopyErrorMessageString(
                    status,
                    nil
                ) as String?
            {
                return message
            }

            return "Keychain-fout \(status)."
        }
    }
}
