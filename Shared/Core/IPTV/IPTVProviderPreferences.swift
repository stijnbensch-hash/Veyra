import Foundation
import CryptoKit

struct IPTVProviderPreferences: Codable, Hashable {
    var hiddenLiveCategoryIDs: Set<String>
    var hiddenLiveChannelIDs: Set<String>

    var hiddenVODCategoryIDs: Set<String>
    var hiddenVODItemIDs: Set<String>

    var hiddenSeriesCategoryIDs: Set<String>
    var hiddenSeriesItemIDs: Set<String>

    init(
        hiddenLiveCategoryIDs: Set<String> = [],
        hiddenLiveChannelIDs: Set<String> = [],
        hiddenVODCategoryIDs: Set<String> = [],
        hiddenVODItemIDs: Set<String> = [],
        hiddenSeriesCategoryIDs: Set<String> = [],
        hiddenSeriesItemIDs: Set<String> = []
    ) {
        self.hiddenLiveCategoryIDs =
            hiddenLiveCategoryIDs

        self.hiddenLiveChannelIDs =
            hiddenLiveChannelIDs

        self.hiddenVODCategoryIDs =
            hiddenVODCategoryIDs

        self.hiddenVODItemIDs =
            hiddenVODItemIDs

        self.hiddenSeriesCategoryIDs =
            hiddenSeriesCategoryIDs

        self.hiddenSeriesItemIDs =
            hiddenSeriesItemIDs
    }

    // MARK: - Live TV

    func isLiveCategoryVisible(
        _ categoryID: String
    ) -> Bool {
        !hiddenLiveCategoryIDs.contains(
            categoryID
        )
    }

    func isLiveChannelVisible(
        _ channelID: String
    ) -> Bool {
        !hiddenLiveChannelIDs.contains(
            channelID
        )
    }

    mutating func setLiveCategory(
        _ categoryID: String,
        visible: Bool
    ) {
        if visible {
            hiddenLiveCategoryIDs.remove(
                categoryID
            )
        } else {
            hiddenLiveCategoryIDs.insert(
                categoryID
            )
        }
    }

    mutating func setLiveChannel(
        _ channelID: String,
        visible: Bool
    ) {
        if visible {
            hiddenLiveChannelIDs.remove(
                channelID
            )
        } else {
            hiddenLiveChannelIDs.insert(
                channelID
            )
        }
    }

    // MARK: - VOD

    func isVODCategoryVisible(
        _ categoryID: String
    ) -> Bool {
        !hiddenVODCategoryIDs.contains(
            categoryID
        )
    }

    func isVODItemVisible(
        _ itemID: String
    ) -> Bool {
        !hiddenVODItemIDs.contains(
            itemID
        )
    }

    mutating func setVODCategory(
        _ categoryID: String,
        visible: Bool
    ) {
        if visible {
            hiddenVODCategoryIDs.remove(
                categoryID
            )
        } else {
            hiddenVODCategoryIDs.insert(
                categoryID
            )
        }
    }

    mutating func setVODItem(
        _ itemID: String,
        visible: Bool
    ) {
        if visible {
            hiddenVODItemIDs.remove(
                itemID
            )
        } else {
            hiddenVODItemIDs.insert(
                itemID
            )
        }
    }

    // MARK: - Series

    func isSeriesCategoryVisible(
        _ categoryID: String
    ) -> Bool {
        !hiddenSeriesCategoryIDs.contains(
            categoryID
        )
    }

    func isSeriesItemVisible(
        _ itemID: String
    ) -> Bool {
        !hiddenSeriesItemIDs.contains(
            itemID
        )
    }

    mutating func setSeriesCategory(
        _ categoryID: String,
        visible: Bool
    ) {
        if visible {
            hiddenSeriesCategoryIDs.remove(
                categoryID
            )
        } else {
            hiddenSeriesCategoryIDs.insert(
                categoryID
            )
        }
    }

    mutating func setSeriesItem(
        _ itemID: String,
        visible: Bool
    ) {
        if visible {
            hiddenSeriesItemIDs.remove(
                itemID
            )
        } else {
            hiddenSeriesItemIDs.insert(
                itemID
            )
        }
    }
}

// MARK: - Preferences Store

struct IPTVProviderPreferencesStore {
    private let defaults: UserDefaults
    private let keyPrefix =
        "veyra.iptv.provider.preferences"

    init(
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
    }

    func load(
        for configuration:
            IPTVStoredConfiguration
    ) -> IPTVProviderPreferences {
        let key = storageKey(
            for: configuration
        )

        guard
            let data = defaults.data(
                forKey: key
            ),
            let preferences =
                try? JSONDecoder().decode(
                    IPTVProviderPreferences.self,
                    from: data
                )
        else {
            return IPTVProviderPreferences()
        }

        return preferences
    }

    func save(
        _ preferences:
            IPTVProviderPreferences,
        for configuration:
            IPTVStoredConfiguration
    ) throws {
        let data = try JSONEncoder()
            .encode(preferences)

        defaults.set(
            data,
            forKey: storageKey(
                for: configuration
            )
        )
    }

    func clear(
        for configuration:
            IPTVStoredConfiguration
    ) {
        defaults.removeObject(
            forKey: storageKey(
                for: configuration
            )
        )
    }

    // MARK: - Storage Key

    private func storageKey(
        for configuration:
            IPTVStoredConfiguration
    ) -> String {
        "\(keyPrefix).\(configuration.providerIdentifier)"
    }
}

// MARK: - Provider Identifier

extension IPTVStoredConfiguration {
    var providerIdentifier: String {
        let identity: String

        switch self {
        case .xtream(let configuration):
            let server =
                configuration
                    .serverURL
                    .absoluteString
                    .lowercased()

            let username =
                configuration.username
                    .lowercased()

            identity =
                "xtream|\(server)|\(username)"

        case .m3u(let configuration):
            identity =
                "m3u|\(configuration.playlistURL.absoluteString)"
        }

        let digest = SHA256.hash(
            data: Data(
                identity.utf8
            )
        )

        return digest.map {
            String(
                format: "%02x",
                $0
            )
        }
        .joined()
    }
}
