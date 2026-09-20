import Foundation
import Security

struct MediaServerStore {
    private let service: String

    private let account =
        "media-servers-v1"

    init() {
        let bundleIdentifier =
            Bundle.main.bundleIdentifier
            ?? "Veyra"

        service =
            "\(bundleIdentifier).mediaservers.configuration"
    }

    // MARK: - Load / Save

    func load() -> [MediaServerAccount] {
        guard
            let data =
                try? readKeychainData(),
            let servers =
                try? JSONDecoder()
                    .decode(
                        [MediaServerAccount].self,
                        from: data
                    )
        else {
            return []
        }

        return servers
    }

    func save(
        _ servers: [MediaServerAccount]
    ) throws {
        let data =
            try JSONEncoder()
                .encode(servers)

        try writeKeychainData(data)
    }

    func add(
        _ server: MediaServerAccount
    ) throws {
        var servers = load()

        servers.removeAll {
            $0.id == server.id
        }

        servers.append(server)

        try save(servers)
    }

    func update(
        _ server: MediaServerAccount
    ) throws {
        var servers = load()

        guard
            let index =
                servers.firstIndex(
                    where: {
                        $0.id == server.id
                    }
                )
        else {
            try add(server)
            return
        }

        servers[index] = server

        try save(servers)
    }

    func remove(
        id: UUID
    ) throws {
        var servers = load()

        servers.removeAll {
            $0.id == id
        }

        try save(servers)
    }

    // MARK: - Keychain

    private func readKeychainData()
        throws -> Data?
    {
        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                account,

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

        if status == errSecItemNotFound {
            return nil
        }

        guard
            status == errSecSuccess
        else {
            throw MediaServerStoreError
                .keychain(status)
        }

        return result as? Data
    }

    private func writeKeychainData(
        _ data: Data
    ) throws {
        let lookupQuery: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                account
        ]

        let updateStatus =
            SecItemUpdate(
                lookupQuery as CFDictionary,
                [kSecValueData as String: data]
                    as CFDictionary
            )

        if updateStatus == errSecSuccess {
            return
        }

        guard
            updateStatus == errSecItemNotFound
        else {
            throw MediaServerStoreError
                .keychain(updateStatus)
        }

        var addQuery =
            lookupQuery

        addQuery[kSecValueData as String] =
            data

        addQuery[kSecAttrAccessible as String] =
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus =
            SecItemAdd(
                addQuery as CFDictionary,
                nil
            )

        guard
            addStatus == errSecSuccess
        else {
            throw MediaServerStoreError
                .keychain(addStatus)
        }
    }
}

enum MediaServerStoreError:
    LocalizedError
{
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
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
