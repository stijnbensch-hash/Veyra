import Foundation
import Security

enum VeyraAPIKey: String, CaseIterable {
    case tmdbReadAccessToken
    case openSubtitlesAPIKey
    case traktClientID
    case traktClientSecret
    case omdbAPIKey

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
        }
    }
}

enum VeyraAPIKeyStore {
    private static let service =
        Bundle.main.bundleIdentifier
        ?? "Veyra"

    static func value(
        for key: VeyraAPIKey
    ) -> String? {
        var query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                key.account,

            kSecReturnData as String:
                true,

            kSecMatchLimit as String:
                kSecMatchLimitOne
        ]

        var result: CFTypeRef?

        let status =
            SecItemCopyMatching(
                query as CFDictionary,
                &result
            )

        query.removeAll()

        guard
            status == errSecSuccess,
            let data = result as? Data,
            let value = String(
                data: data,
                encoding: .utf8
            )
        else {
            return nil
        }

        let trimmed =
            value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return trimmed.isEmpty
            ? nil
            : trimmed
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

        let baseQuery: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                key.account
        ]

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
    }

    static func remove(
        _ key: VeyraAPIKey
    ) throws {
        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                key.account
        ]

        let status =
            SecItemDelete(
                query as CFDictionary
            )

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
