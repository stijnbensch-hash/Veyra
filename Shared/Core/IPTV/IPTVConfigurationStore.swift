import Foundation
import Security

enum IPTVStoredConfiguration: Hashable {
    case m3u(M3UConfiguration)
    case xtream(XtreamConfiguration)
}

// MARK: - Stored Provider

struct IPTVStoredProvider: Identifiable, Hashable {
    let id: UUID
    var configuration: IPTVStoredConfiguration

    var displayName: String {
        switch configuration {
        case .m3u(let configuration):
            return configuration.displayName

        case .xtream(let configuration):
            return configuration.displayName
        }
    }
}

// MARK: - Configuration Store

struct IPTVConfigurationStore {
    private let service: String

    private let providersAccount =
        "iptv-providers-v1"

    private let legacyAccount =
        "active-iptv-configuration"

    init() {
        let bundleIdentifier =
            Bundle.main.bundleIdentifier
            ?? "Veyra"

        service =
            "\(bundleIdentifier).iptv.configuration"
    }

    // MARK: - Compatibility

    func load()
        throws -> IPTVStoredConfiguration?
    {
        let state =
            try loadState()

        guard !state.providers.isEmpty else {
            return nil
        }

        if
            let activeProviderID =
                state.activeProviderID,
            let provider =
                state.providers.first(
                    where: {
                        $0.id ==
                            activeProviderID
                    }
                )
        {
            return try provider
                .configuration
                .configuration()
        }

        return try state
            .providers[0]
            .configuration
            .configuration()
    }

    func save(
        _ configuration:
            IPTVStoredConfiguration
    ) throws {
        var state =
            try loadState()

        if
            let activeProviderID =
                state.activeProviderID,
            let index =
                state.providers.firstIndex(
                    where: {
                        $0.id ==
                            activeProviderID
                    }
                )
        {
            state.providers[index]
                .configuration =
                StoredConfigurationPayload(
                    configuration:
                        configuration
                )

            try saveState(state)
            return
        }

        if !state.providers.isEmpty {
            state.providers[0]
                .configuration =
                StoredConfigurationPayload(
                    configuration:
                        configuration
                )

            state.activeProviderID =
                state.providers[0].id

            try saveState(state)
            return
        }

        let providerID = UUID()

        state.providers.append(
            StoredProviderPayload(
                id: providerID,
                configuration:
                    StoredConfigurationPayload(
                        configuration:
                            configuration
                    )
            )
        )

        state.activeProviderID =
            providerID

        try saveState(state)
    }

    func clear() throws {
        try deleteKeychainItem(
            account: providersAccount
        )

        try deleteKeychainItem(
            account: legacyAccount
        )
    }

    // The Hub syncs provider credentials through its authenticated settings
    // document. Keep the raw payload out of UserDefaults and iCloud KVS.
    func exportForHub() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(loadState())
    }

    func importFromHub(_ data: Data) throws {
        var state = try JSONDecoder().decode(StoredProvidersPayload.self, from: data)
        state.normalizeActiveProvider()
        for provider in state.providers {
            _ = try provider.configuration.configuration()
        }

        // Bescherming: een Hub-sync mag een werkende lokale provider-lijst
        // nooit stilzwijgend leegmaken. Als een ander apparaat (nog) geen
        // providers heeft doorgegeven (bijv. eerste sync, of lokaal net
        // gewist) terwijl hier al wel een geldige provider actief is, wordt
        // die import genegeerd — anders verdwijnen de Xtream-inloggegevens
        // hier zonder foutmelding en breekt live-TV stilletjes.
        if state.providers.isEmpty {
            let currentState = try loadState()
            guard currentState.providers.isEmpty else {
                #if DEBUG
                print("[IPTVConfigurationStore] Hub-import genegeerd: externe payload heeft geen providers, lokaal wel (\(currentState.providers.count)).")
                #endif
                throw IPTVConfigurationStoreError.invalidStoredData
            }
        }

        #if DEBUG
        let currentForLog = try? loadState()
        for provider in state.providers {
            if case .xtream(let config) = try provider.configuration.configuration() {
                let matchesExisting = currentForLog?.providers.contains {
                    (try? $0.configuration.configuration()).map {
                        if case .xtream(let existing) = $0 {
                            return existing.serverURL == config.serverURL && existing.username == config.username
                        }
                        return false
                    } ?? false
                } ?? false
                print("[IPTVConfigurationStore] Hub-import: xtream provider '\(config.displayName)' server=\(config.serverURL.absoluteString) user=\(config.username) alreadyPresentLocally=\(matchesExisting)")
            }
        }
        #endif

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        try writeLocalKeychainData(try encoder.encode(state), account: providersAccount)
    }

    // MARK: - Multiple Providers

    func loadProviders()
        throws -> [IPTVStoredProvider]
    {
        let state =
            try loadState()

        return try state.providers.map {
            provider in

            IPTVStoredProvider(
                id: provider.id,
                configuration:
                    try provider
                        .configuration
                        .configuration()
            )
        }
    }

    func loadProvider(
        id: UUID
    ) throws -> IPTVStoredProvider? {
        let state =
            try loadState()

        guard
            let provider =
                state.providers.first(
                    where: {
                        $0.id == id
                    }
                )
        else {
            return nil
        }

        return IPTVStoredProvider(
            id: provider.id,
            configuration:
                try provider
                    .configuration
                    .configuration()
        )
    }

    @discardableResult
    func addProvider(
        _ configuration:
            IPTVStoredConfiguration
    ) throws -> IPTVStoredProvider {
        var state =
            try loadState()

        let provider =
            IPTVStoredProvider(
                id: UUID(),
                configuration:
                    configuration
            )

        state.providers.append(
            StoredProviderPayload(
                id: provider.id,
                configuration:
                    StoredConfigurationPayload(
                        configuration:
                            configuration
                    )
            )
        )

        state.activeProviderID =
            provider.id

        try saveState(state)

        return provider
    }

    func updateProvider(
        id: UUID,
        configuration:
            IPTVStoredConfiguration
    ) throws {
        var state =
            try loadState()

        guard
            let index =
                state.providers.firstIndex(
                    where: {
                        $0.id == id
                    }
                )
        else {
            throw IPTVConfigurationStoreError
                .providerNotFound
        }

        state.providers[index]
            .configuration =
            StoredConfigurationPayload(
                configuration:
                    configuration
            )

        try saveState(state)
    }

    func removeProvider(
        id: UUID
    ) throws {
        var state =
            try loadState()

        guard
            let index =
                state.providers.firstIndex(
                    where: {
                        $0.id == id
                    }
                )
        else {
            throw IPTVConfigurationStoreError
                .providerNotFound
        }

        state.providers.remove(
            at: index
        )

        if state.activeProviderID == id {
            state.activeProviderID =
                state.providers.first?.id
        }

        state.normalizeActiveProvider()

        try saveState(state)
    }

    // MARK: - Active Provider

    func activeProviderID()
        throws -> UUID?
    {
        let state =
            try loadState()

        return state.activeProviderID
    }

    func setActiveProvider(
        id: UUID
    ) throws {
        var state =
            try loadState()

        guard
            state.providers.contains(
                where: {
                    $0.id == id
                }
            )
        else {
            throw IPTVConfigurationStoreError
                .providerNotFound
        }

        state.activeProviderID = id

        try saveState(state)
    }

    // MARK: - State

    private func loadState()
        throws -> StoredProvidersPayload
    {
        if
            let data =
                try readKeychainData(
                    account:
                        providersAccount
                )
        {
            var state =
                try JSONDecoder()
                    .decode(
                        StoredProvidersPayload.self,
                        from: data
                    )

            state.normalizeActiveProvider()

            for provider in state.providers {
                _ =
                    try provider
                        .configuration
                        .configuration()
            }

            return state
        }

        return try migrateLegacyState()
    }

    private func saveState(
        _ state:
            StoredProvidersPayload
    ) throws {
        var normalizedState =
            state

        normalizedState
            .normalizeActiveProvider()

        let data =
            try JSONEncoder()
                .encode(
                    normalizedState
                )

        if VeyraHubSyncService.shared.isActive {
            try writeLocalKeychainData(data, account: providersAccount)
        } else {
            try writeKeychainData(data, account: providersAccount)
        }
    }

    // MARK: - Legacy Migration

    private func migrateLegacyState()
        throws -> StoredProvidersPayload
    {
        guard
            let legacyData =
                try readKeychainData(
                    account:
                        legacyAccount
                )
        else {
            return StoredProvidersPayload(
                providers: [],
                activeProviderID: nil
            )
        }

        let legacyPayload =
            try JSONDecoder()
                .decode(
                    StoredConfigurationPayload.self,
                    from:
                        legacyData
                )

        _ =
            try legacyPayload
                .configuration()

        let providerID =
            UUID()

        let migratedState =
            StoredProvidersPayload(
                providers: [
                    StoredProviderPayload(
                        id: providerID,
                        configuration:
                            legacyPayload
                    )
                ],
                activeProviderID:
                    providerID
            )

        try saveState(
            migratedState
        )

        try? deleteKeychainItem(
            account:
                legacyAccount
        )

        return migratedState
    }

    // MARK: - Keychain Read

    // Probeert eerst het gesynchroniseerde (iCloud Keychain) item; valt
    // terug op een niet-gesynchroniseerd item van vóór deze wijziging.
    private func readKeychainData(
        account: String
    ) throws -> Data? {
        if VeyraHubSyncService.shared.isActive {
            if let local = try readKeychainData(account: account, synchronizable: false) {
                return local
            }
            return try? readKeychainData(account: account, synchronizable: true)
        }
        if let synced = try readKeychainData(account: account, synchronizable: true) {
            return synced
        }
        return try readKeychainData(account: account, synchronizable: false)
    }

    private func readKeychainData(
        account: String,
        synchronizable: Bool
    ) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                account,

            kSecAttrSynchronizable as String:
                synchronizable,

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
            throw IPTVConfigurationStoreError
                .keychainError(
                    status
                )
        }

        guard
            let data =
                result as? Data
        else {
            throw IPTVConfigurationStoreError
                .invalidStoredData
        }

        return data
    }

    // MARK: - Keychain Write

    private func writeLocalKeychainData(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
        let status = SecItemUpdate(query as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else {
            throw IPTVConfigurationStoreError.keychainError(status)
        }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw IPTVConfigurationStoreError.keychainError(addStatus)
        }
    }

    /// Schrijft naar het gesynchroniseerde (iCloud Keychain) item, zodat
    /// IPTV-inloggegevens automatisch meegaan naar andere apparaten met
    /// hetzelfde iCloud-account. `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
    /// is niet te combineren met `kSecAttrSynchronizable: true`, dus nieuwe
    /// items gebruiken `kSecAttrAccessibleWhenUnlocked`.
    private func writeKeychainData(
        _ data: Data,
        account: String
    ) throws {
        let lookupQuery: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                account,

            kSecAttrSynchronizable as String:
                true
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String:
                data
        ]

        let updateStatus =
            SecItemUpdate(
                lookupQuery as CFDictionary,
                updateAttributes as CFDictionary
            )

        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw IPTVConfigurationStoreError
                .keychainError(
                    updateStatus
                )
        }

        // Eenmalige opruiming: een niet-gesynchroniseerd item van vóór deze
        // wijziging staat de nieuwe (gesynchroniseerde) toevoeging niet in
        // de weg, maar blijft anders als verouderd duplicaat achter.
        try? deleteKeychainItem(account: account, synchronizable: false)

        var addQuery =
            lookupQuery

        addQuery[
            kSecValueData as String
        ] =
            data

        addQuery[
            kSecAttrAccessible as String
        ] =
            kSecAttrAccessibleWhenUnlocked

        let addStatus =
            SecItemAdd(
                addQuery as CFDictionary,
                nil
            )

        guard
            addStatus == errSecSuccess
        else {
            throw IPTVConfigurationStoreError
                .keychainError(
                    addStatus
                )
        }
    }

    // MARK: - Keychain Delete

    private func deleteKeychainItem(
        account: String
    ) throws {
        try deleteKeychainItem(account: account, synchronizable: true)
        try deleteKeychainItem(account: account, synchronizable: false)
    }

    private func deleteKeychainItem(
        account: String,
        synchronizable: Bool
    ) throws {
        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                account,

            kSecAttrSynchronizable as String:
                synchronizable
        ]

        let status =
            SecItemDelete(
                query as CFDictionary
            )

        guard
            status == errSecSuccess ||
            status == errSecItemNotFound
        else {
            throw IPTVConfigurationStoreError
                .keychainError(
                    status
                )
        }
    }
}

// MARK: - Providers Payload

private struct StoredProvidersPayload:
    Codable
{
    let version: Int

    var providers:
        [StoredProviderPayload]

    var activeProviderID:
        UUID?

    init(
        providers:
            [StoredProviderPayload],
        activeProviderID:
            UUID?
    ) {
        version = 1
        self.providers =
            providers
        self.activeProviderID =
            activeProviderID
    }

    mutating func normalizeActiveProvider() {
        guard !providers.isEmpty else {
            activeProviderID = nil
            return
        }

        if
            let activeProviderID,
            providers.contains(
                where: {
                    $0.id ==
                        activeProviderID
                }
            )
        {
            return
        }

        activeProviderID =
            providers[0].id
    }
}

// MARK: - Provider Payload

private struct StoredProviderPayload:
    Codable
{
    let id: UUID

    var configuration:
        StoredConfigurationPayload
}

// MARK: - Stored Configuration Payload

private struct StoredConfigurationPayload:
    Codable
{
    enum Kind: String, Codable {
        case m3u
        case xtream
    }

    let kind: Kind

    let displayName: String?

    let playlistURL: String?

    let serverURL: String?
    let username: String?
    let password: String?

    init(
        configuration:
            IPTVStoredConfiguration
    ) {
        switch configuration {
        case .m3u(
            let configuration
        ):
            kind = .m3u

            displayName =
                configuration.displayName

            playlistURL =
                configuration
                    .playlistURL
                    .absoluteString

            serverURL = nil
            username = nil
            password = nil

        case .xtream(
            let configuration
        ):
            kind = .xtream

            displayName =
                configuration.displayName

            playlistURL = nil

            serverURL =
                configuration
                    .serverURL
                    .absoluteString

            username =
                configuration.username

            password =
                configuration.password
        }
    }

    func configuration()
        throws -> IPTVStoredConfiguration
    {
        let resolvedDisplayName =
            normalizedDisplayName(
                displayName
            )

        switch kind {
        case .m3u:
            guard
                let playlistURL,
                let url =
                    URL(
                        string:
                            playlistURL
                    )
            else {
                throw IPTVConfigurationStoreError
                    .invalidStoredData
            }

            return .m3u(
                M3UConfiguration(
                    displayName:
                        resolvedDisplayName,
                    playlistURL:
                        url
                )
            )

        case .xtream:
            guard
                let serverURL,
                let username,
                let password,
                let url =
                    URL(
                        string:
                            serverURL
                    )
            else {
                throw IPTVConfigurationStoreError
                    .invalidStoredData
            }

            return .xtream(
                XtreamConfiguration(
                    displayName:
                        resolvedDisplayName,
                    serverURL:
                        url,
                    username:
                        username,
                    password:
                        password
                )
            )
        }
    }

    private func normalizedDisplayName(
        _ value: String?
    ) -> String {
        let trimmed =
            value?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            let trimmed,
            !trimmed.isEmpty
        else {
            return "IPTV"
        }

        return trimmed
    }
}

// MARK: - Errors

enum IPTVConfigurationStoreError:
    LocalizedError
{
    case invalidStoredData
    case providerNotFound
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidStoredData:
            return
                "De opgeslagen IPTV-configuratie is ongeldig."

        case .providerNotFound:
            return
                "De IPTV-provider kon niet worden gevonden."

        case .keychainError(
            let status
        ):
            if
                let message =
                    SecCopyErrorMessageString(
                        status,
                        nil
                    ) as String?
            {
                return
                    "Keychain-fout: \(message)"
            }

            return
                "De IPTV-configuratie kon niet veilig worden opgeslagen."
        }
    }
}
