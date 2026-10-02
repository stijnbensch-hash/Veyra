import Foundation
import Combine
import CryptoKit

struct VeyraGuideChannel: Identifiable, Hashable {
    let id: String
    let channel: IPTVChannel
    let categoryID: String
}

nonisolated private struct VeyraLiveCatalog: Codable, Sendable {
    let channels: [IPTVChannel]
    let categories: [IPTVCategory]
}

nonisolated private struct VeyraCatalogSnapshot: Codable, Sendable {
    let savedAt: Date
    let catalog: VeyraLiveCatalog
}

nonisolated private struct VeyraGuideSnapshot: Codable, Sendable {
    let savedAt: Date
    let programmes: [String: [VeyraEPGProgramme]]
}

@MainActor
final class VeyraEPGStore: ObservableObject {
    @Published private(set) var channels: [VeyraGuideChannel] = []
    /// Alle providerzenders, ongefilterd door de Live TV-zichtbaarheidsinstellingen
    /// van de gebruiker (`isLiveCategoryVisible`/`isLiveChannelVisible`). Bedoeld voor
    /// gebruik buiten de Live TV-gids zelf, zoals sportwedstrijd-kanaalmatching, die
    /// alle kanalen met een naam-match moet kunnen vinden, ook verborgen zenders.
    @Published private(set) var allChannels: [VeyraGuideChannel] = []
    @Published private(set) var categories: [IPTVCategory] = []
    @Published private(set) var providers: [IPTVStoredProvider] = []
    @Published private(set) var activeProviderID: UUID?
    @Published private(set) var programmeIndex: [String: [VeyraEPGProgramme]] = [:]

    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var favoriteOrder: [String] = []
    @Published private(set) var recent: [String] = []

    @Published private(set) var loadingChannels = false
    @Published private(set) var loadingGuide = false
    @Published private(set) var channelError: String?
    @Published private(set) var guideMessage: String?

    @Published var selectedCategory = "favorites"
    @Published var searchText = ""
    @Published var reloadID = UUID()
    @Published var windowStart = VeyraEPGStore.currentWindow()

    let windowDuration: TimeInterval = 3 * 3_600

    private let service = IPTVService()
    private let configStore = IPTVConfigurationStore()
    private let preferencesStore = IPTVProviderPreferencesStore()
    private let epgService = VeyraEPGService()

    /// `UserDefaults`/`CFPreferences` crasht hard op tvOS zodra één sleutel
    /// >= 1 MB wordt weggeschreven ("byte count limit reached"), en zelfs
    /// een controle die daaronder blijft loste dit niet betrouwbaar op: met
    /// meerdere providers/veel programmadata liep het *totaal* van alle
    /// sleutels samen alsnog op, en het opruimen daarvan met
    /// `dictionaryRepresentation()` leest de hele voorkeurendatabase
    /// synchroon in het geheugen op de main thread — met deze blobs erin
    /// kon dát de app juist laten hangen bij het opstarten. Daarom
    /// schrijven we deze snapshot niet meer naar UserDefaults; `IPTVDiskCache`
    /// (los bestand, geen CFPreferences-limiet en geen main-thread-risico)
    /// is en blijft de betrouwbare cache. VeyraHubSyncService synct deze
    /// twee sleutels dus niet meer mee tussen apparaten — elk apparaat
    /// haalt de gids/catalogus zelf op, wat trager kan zijn bij een koude
    /// start op een nieuw apparaat, maar niet meer kan crashen/hangen.

    private static func cacheInterval(
        key: String,
        fallback: IPTVCacheRefreshInterval
    ) -> TimeInterval {
        let raw = UserDefaults.standard.string(forKey: key) ?? fallback.rawValue
        return (IPTVCacheRefreshInterval(rawValue: raw) ?? fallback).seconds
    }

    private static func catalogUsesCurrentCredentials(
        _ catalog: VeyraLiveCatalog,
        configuration: IPTVStoredConfiguration
    ) -> Bool {
        guard case .xtream(let account) = configuration else { return true }
        guard let channel = catalog.channels.first(where: { $0.sourceType == .xtream }) else { return false }
        let expectedBase = account.serverURL
            .appendingPathComponent("live")
            .appendingPathComponent(account.username)
            .appendingPathComponent(account.password)
        let actualBase = channel.streamURL.deletingLastPathComponent()
        return actualBase.scheme == expectedBase.scheme
            && actualBase.host == expectedBase.host
            && actualBase.port == expectedBase.port
            && actualBase.pathComponents == expectedBase.pathComponents
    }

    private var providerKey: String?
    private var generation = UUID()
    private var completedReloadID: UUID?
    private var loadedAt: Date?
    private var loadedConfiguration: IPTVStoredConfiguration?
    private var loadedPreferences: IPTVProviderPreferences?

    var windowEnd: Date {
        windowStart.addingTimeInterval(windowDuration)
    }

    var providerName: String {
        providers.first {
            $0.id == activeProviderID
        }?.displayName ?? "Provider kiezen"
    }

    // MARK: - Favorites

    var favoriteRows: [VeyraGuideChannel] {
        let channelsByID = Dictionary(
            uniqueKeysWithValues: channels.map {
                ($0.id, $0)
            }
        )

        var result: [VeyraGuideChannel] = []
        var added = Set<String>()

        // Eerst de expliciet opgeslagen volgorde.
        for id in favoriteOrder {
            guard
                favorites.contains(id),
                let row = channelsByID[id],
                added.insert(id).inserted
            else {
                continue
            }

            result.append(row)
        }

        // Favorieten zonder opgeslagen positie achteraan toevoegen.
        for row in channels {
            guard
                favorites.contains(row.id),
                added.insert(row.id).inserted
            else {
                continue
            }

            result.append(row)
        }

        return result
    }

    var visibleChannels: [VeyraGuideChannel] {
        var values: [VeyraGuideChannel]

        switch selectedCategory {
        case "favorites":
            values = favoriteRows

        case "recent":
            let order = Dictionary(
                uniqueKeysWithValues:
                    recent.enumerated().map {
                        ($1, $0)
                    }
            )

            values = channels
                .filter {
                    order[$0.id] != nil
                }
                .sorted {
                    (order[$0.id] ?? 0)
                    <
                    (order[$1.id] ?? 0)
                }

        case "all":
            values = channels

        default:
            values = channels.filter {
                "group:" + $0.categoryID == selectedCategory
            }
        }

        let query = searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !query.isEmpty else {
            return values
        }

        return values.filter { row in
            row.channel.name
                .localizedCaseInsensitiveContains(query)
            ||
            programmes(for: row).contains { programme in
                programme.start < windowEnd
                &&
                programme.end > windowStart
                &&
                (
                    programme.title
                        .localizedCaseInsensitiveContains(query)
                    ||
                    programme.subtitle
                        .localizedCaseInsensitiveContains(query)
                )
            }
        }
    }

    func programmes(
        for row: VeyraGuideChannel
    ) -> [VeyraEPGProgramme] {
        let id = row.channel.tvgID?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        ?? ""

        return programmeIndex[id] ?? []
    }

    // MARK: - Reload

    /// - Parameter force: negeert de "verversen"-instellingen
    /// (`refreshChannelsIntervalKey`/`refreshEPGIntervalKey`) en de korte
    /// 15-minuten-throttle hieronder, en haalt zenderlijst + gids altijd
    /// opnieuw bij de provider op. Gebruikt door de expliciete
    /// "Vernieuwen"-knoppen in Live TV en de kanaal-/VOD-beheerschermen --
    /// zonder deze parameter deed zo'n knop feitelijk niets zolang het
    /// ingestelde interval nog niet verstreken was, want `reload()` las de
    /// schijfcache dan gewoon opnieuw in.
    func reload(force: Bool = false) async {
        let token = UUID()
        generation = token

        let requestedReloadID = reloadID

        do {
            providers = try configStore.loadProviders()

            activeProviderID =
                try configStore.activeProviderID()

            guard
                let configuration =
                    try configStore.load()
            else {
                clear()

                channelError =
                    "Geen IPTV-provider ingesteld. Voeg een provider toe via Instellingen > Bronnen > IPTV."

                return
            }

            let preferences =
                preferencesStore.load(
                    for: configuration
                )

            // Bij dezelfde reload hoeven zenders niet opnieuw
            // gedownload te worden.
            if !force,
               completedReloadID == requestedReloadID,
               configuration == loadedConfiguration,
               preferences == loadedPreferences,
               let loadedAt,
               Date().timeIntervalSince(loadedAt) < 900 {
                providerKey = configuration.providerIdentifier
                loadProviderState()
                return
            }

            let changedProvider =
                providerKey
                != configuration.providerIdentifier

            // BELANGRIJK:
            // providerKey eerst instellen.
            // Alle favorietenkeys zijn hiervan afhankelijk.
            providerKey =
                configuration.providerIdentifier

            if changedProvider {
                channels = []
                categories = []
                programmeIndex = [:]
            }

            channelError = nil
            guideMessage = nil

            loadingChannels = true
            loadingGuide = false

            loadProviderState()

            if changedProvider {
                selectedCategory = "favorites"
                searchText = ""
                windowStart = Self.currentWindow()
            }

            let cacheKey = "live-catalog-v1-\(configuration.providerIdentifier)"
            let diskCatalog = await IPTVDiskCache.readAsync(VeyraLiveCatalog.self, key: cacheKey)
            guard generation == token, !Task.isCancelled else { return }
            let syncedCatalog = UserDefaults.standard.data(
                forKey: VeyraIPTVSnapshot.catalogPrefix + configuration.providerIdentifier
            ).flatMap { VeyraIPTVSnapshot.decode(VeyraCatalogSnapshot.self, from: $0) }
            var catalogSavedAt: Date?
            if let snapshot = syncedCatalog,
               Self.catalogUsesCurrentCredentials(snapshot.catalog, configuration: configuration),
               snapshot.savedAt.timeIntervalSince(diskCatalog?.savedAt ?? .distantPast) > 60 {
                // Een ander apparaat kan inmiddels nieuwe kanalen hebben.
                // Toon ze meteen, maar haal daarna de volledige catalogus op.
                applyCatalog(snapshot.catalog, configuration: configuration, preferences: preferences)
                loadingChannels = false
            } else if let cached = diskCatalog,
                      Self.catalogUsesCurrentCredentials(cached.value, configuration: configuration) {
                applyCatalog(cached.value, configuration: configuration, preferences: preferences)
                catalogSavedAt = cached.savedAt
                loadingChannels = false
            } else if let snapshot = syncedCatalog,
                      Self.catalogUsesCurrentCredentials(snapshot.catalog, configuration: configuration) {
                applyCatalog(snapshot.catalog, configuration: configuration, preferences: preferences)
                loadingChannels = false
            }
            let guideCacheKey = "live-guide-v1-\(configuration.providerIdentifier)"
            let diskGuide = await IPTVDiskCache.readAsync([String: [VeyraEPGProgramme]].self,
                                               key: guideCacheKey)
            guard generation == token, !Task.isCancelled else { return }
            let syncedGuide = UserDefaults.standard.data(
                forKey: VeyraIPTVSnapshot.guidePrefix + configuration.providerIdentifier
            ).flatMap { VeyraIPTVSnapshot.decode(VeyraGuideSnapshot.self, from: $0) }
            var guideSavedAt: Date?
            if let snapshot = syncedGuide,
               snapshot.savedAt.timeIntervalSince(diskGuide?.savedAt ?? .distantPast) > 60 {
                programmeIndex = snapshot.programmes
                guideSavedAt = snapshot.savedAt
            } else if let cachedGuide = diskGuide {
                programmeIndex = cachedGuide.value
                guideSavedAt = cachedGuide.savedAt
            } else if let snapshot = syncedGuide {
                programmeIndex = snapshot.programmes
                guideSavedAt = snapshot.savedAt
            }

            let channelInterval = Self.cacheInterval(
                key: IPTVPlaybackSettingsDefaults.refreshChannelsIntervalKey,
                fallback: .sixHours)
            let guideInterval = Self.cacheInterval(
                key: IPTVPlaybackSettingsDefaults.refreshEPGIntervalKey,
                fallback: .twelveHours)
            let guideIsFresh = guideSavedAt.map { savedAt in
                Date().timeIntervalSince(savedAt) < guideInterval
                    && (catalogSavedAt.map { savedAt >= $0 } ?? true)
            } ?? false
            if !force, let catalogSavedAt, !allChannels.isEmpty,
               Date().timeIntervalSince(catalogSavedAt) < channelInterval {
                loadedConfiguration = configuration
                loadedPreferences = preferences
                loadingChannels = false
                await loadGuide(configuration: configuration, token: token,
                                useCachedGuide: guideIsFresh)
                guard generation == token, !Task.isCancelled else { return }
                completedReloadID = requestedReloadID
                loadedAt = Date()
                return
            }

            let receivedChannels: [IPTVChannel]
            var receivedCategories: [IPTVCategory]

            switch configuration {
            case .xtream(let value):
                receivedCategories =
                    try await service
                        .loadXtreamLiveCategories(
                            configuration: value
                        )

                try Task.checkCancellation()

                receivedChannels =
                    try await service
                        .loadXtreamLiveChannels(
                            configuration: value
                        )

            case .m3u(let value):
                receivedChannels =
                    try await service
                        .loadM3UChannels(
                            configuration: value
                        )

                let names = Set(
                    receivedChannels.map(
                        \.iptvPreferenceGroupName
                    )
                )

                receivedCategories =
                    names
                        .sorted()
                        .map {
                            IPTVCategory(
                                id:
                                    IPTVChannel
                                        .iptvPreferenceGroupID(
                                            $0
                                        ),
                                name: $0,
                                contentType: .live
                            )
                        }
            }

            try Task.checkCancellation()

            guard generation == token else {
                return
            }

            let catalog = VeyraLiveCatalog(
                channels: receivedChannels,
                categories: receivedCategories
            )
            applyCatalog(
                catalog,
                configuration: configuration,
                preferences: preferences
            )
            IPTVDiskCache.write(catalog, key: cacheKey)

            loadingChannels = false

            loadedConfiguration = configuration
            loadedPreferences = preferences

            // Een nieuwe zenderlijst kan nieuwe EPG-ID's bevatten: haal de
            // gids dan mee op, ook als de vorige gids nog binnen zijn TTL valt.
            await loadGuide(configuration: configuration, token: token)

            guard generation == token, !Task.isCancelled else { return }

            completedReloadID = requestedReloadID
            loadedAt = Date()

        } catch {
            guard generation == token else { return }

            loadingChannels = false
            loadingGuide = false

            if !Task.isCancelled {
                if !channels.isEmpty {
                    // The saved catalog is still usable while the provider is offline.
                    channelError = nil
                    guideMessage = "Opgeslagen zenders worden getoond; verversen is tijdelijk niet mogelijk."
                    if let configuration = try? configStore.load() {
                        await loadGuide(configuration: configuration, token: token)
                    }
                } else if let failure = error as? IPTVServiceError {
                    channelError = failure.localizedDescription
                } else if let failure = error as? XtreamError {
                    channelError = failure.localizedDescription
                } else {
                    channelError = "De providers of zenders konden niet worden geladen. Controleer de verbinding en kies Vernieuwen."
                }
            }
        }
    }

    private func applyCatalog(
        _ catalog: VeyraLiveCatalog,
        configuration: IPTVStoredConfiguration,
        preferences: IPTVProviderPreferences
    ) {
        var seen = Set<String>()
        var seenAll = Set<String>()
        var rows: [VeyraGuideChannel] = []
        var allRows: [VeyraGuideChannel] = []

            for channel
                in catalog.channels
                where channel.contentType == .live
            {
                let groupID: String

                switch configuration {
                case .m3u:
                    groupID =
                        IPTVChannel
                            .iptvPreferenceGroupID(
                                channel.iptvPreferenceGroupName
                            )

                case .xtream:
                    groupID =
                        channel.group ?? ""
                }

                // M3U kan dezelfde tvg-id gebruiken
                // voor bijvoorbeeld HD/SD-varianten.
                let identity =
                    channel.sourceType == .m3u
                    ?
                    "\(channel.id)|\(channel.streamURL.absoluteString)"
                    :
                    channel.id

                let id = SHA256
                    .hash(
                        data: Data(identity.utf8)
                    )
                    .map {
                        String(
                            format: "%02x",
                            $0
                        )
                    }
                    .joined()

                let row = VeyraGuideChannel(
                    id: id,
                    channel: channel,
                    categoryID: groupID
                )

                // Ongefilterde lijst (alle providerzenders, ook zenders die de
                // gebruiker niet zichtbaar heeft gezet in Live TV) — gebruikt door
                // functionaliteit zoals sportwedstrijd-kanaalmatching die niet
                // beperkt mag worden door de Live TV-zichtbaarheidsinstellingen.
                if seenAll.insert(id).inserted {
                    allRows.append(row)
                }

                guard
                    preferences
                        .isLiveCategoryVisible(
                            groupID
                        ),
                    preferences
                        .isLiveChannelVisible(
                            channel.id
                        )
                else {
                    continue
                }

                if seen.insert(id).inserted {
                    rows.append(row)
                }
            }

            channels = rows
            allChannels = allRows

            normalizeFavoriteOrder()

            let groupsWithChannels =
                Set(
                    rows.map(
                        \.categoryID
                    )
                )

            var seenGroups =
                Set<String>()

            let visibleCategories =
                catalog.categories.filter {
                    preferences
                        .isLiveCategoryVisible(
                            $0.id
                        )
                    &&
                    groupsWithChannels
                        .contains(
                            $0.id
                        )
                    &&
                    seenGroups
                        .insert(
                            $0.id
                        )
                        .inserted
                }

            categories =
                visibleCategories.sorted {
                    $0.name
                        .localizedStandardCompare(
                            $1.name
                        )
                    == .orderedAscending
                }

            if selectedCategory.hasPrefix("group:"),
               !categories.contains(
                    where: {
                        "group:" + $0.id
                        == selectedCategory
                    }
               ) {
                selectedCategory =
                    "favorites"
            }

    }

    // MARK: - Provider-specific state

    private func loadProviderState() {
        // Favorieten/volgorde/recent staan lokaal; tussen apparaten gaan
        // ze mee via de gekoppelde VeyraHub-server (VeyraHubSyncService,
        // "livetv"-document) — geen directe iCloud-fallback meer (zie
        // CloudSettingsSync, verwijderd, en ChannelNameOverrideStore).
        favorites = Set(
            UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        )

        favoriteOrder = unique(
            UserDefaults.standard.stringArray(forKey: favoriteOrderKey) ?? []
        )

        recent = Array(
            (UserDefaults.standard.stringArray(forKey: recentKey) ?? []).prefix(40)
        )
    }

    private func saveFavorites() {
        UserDefaults.standard.set(
            Array(favorites),
            forKey: favoritesKey
        )
    }

    private func saveFavoriteOrder() {
        favoriteOrder =
            unique(
                favoriteOrder.filter {
                    favorites.contains($0)
                }
            )

        UserDefaults.standard.set(
            favoriteOrder,
            forKey: favoriteOrderKey
        )
    }

    private func normalizeFavoriteOrder() {
        favoriteOrder =
            favoriteOrder.filter {
                favorites.contains($0)
            }

        // Favorieten die nog geen orderpositie hebben
        // achteraan toevoegen.
        for row in channels {
            if favorites.contains(row.id),
               !favoriteOrder.contains(row.id)
            {
                favoriteOrder.append(
                    row.id
                )
            }
        }

        saveFavoriteOrder()
    }

    private func unique(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()

        return values.filter {
            seen.insert($0).inserted
        }
    }

    // MARK: - Channel visibility

    /// Verbergt of toont een zender rechtstreeks vanuit de zenderlijst zelf (contextmenu),
    /// zonder eerst naar "Live TV beheren" te moeten gaan. Bewaart dezelfde voorkeur als
    /// dat beheerscherm (`IPTVProviderPreferences.hiddenLiveChannelIDs`) en past de
    /// gefilterde lijst meteen aan -- geen reload nodig, dus geen hapering/deselectie.
    func setChannelVisible(_ channel: IPTVChannel, visible: Bool) {
        guard let configuration = loadedConfiguration else { return }
        var preferences = loadedPreferences ?? preferencesStore.load(for: configuration)
        preferences.setLiveChannel(channel.id, visible: visible)

        do {
            try preferencesStore.save(preferences, for: configuration)
        } catch {
            channelError = error.localizedDescription
            return
        }

        loadedPreferences = preferences

        channels = allChannels.filter {
            preferences.isLiveCategoryVisible($0.categoryID)
                && preferences.isLiveChannelVisible($0.channel.id)
        }
        normalizeFavoriteOrder()

        let groupsWithChannels = Set(channels.map(\.categoryID))
        categories = categories.filter {
            groupsWithChannels.contains($0.id) && preferences.isLiveCategoryVisible($0.id)
        }
        if selectedCategory.hasPrefix("group:"),
           !categories.contains(where: { "group:" + $0.id == selectedCategory }) {
            selectedCategory = "favorites"
        }
    }

    // MARK: - Provider

    func selectProvider(
        _ provider: IPTVStoredProvider
    ) {
        do {
            try configStore.setActiveProvider(
                id: provider.id
            )

            NotificationCenter.default.post(
                name:
                    .iptvConfigurationDidChange,
                object: nil
            )

        } catch {
            channelError =
                error.localizedDescription
        }
    }

    // MARK: - Favorite management

    func toggleFavorite(
        _ row: VeyraGuideChannel
    ) {
        guard providerKey != nil else {
            return
        }

        if favorites.contains(row.id) {
            favorites.remove(
                row.id
            )

            favoriteOrder.removeAll {
                $0 == row.id
            }

        } else {
            favorites.insert(
                row.id
            )

            if !favoriteOrder.contains(
                row.id
            ) {
                favoriteOrder.append(
                    row.id
                )
            }
        }

        saveFavorites()
        saveFavoriteOrder()
    }

    // iOS gebruikt deze na drag-and-drop.
    func setFavoriteOrder(
        _ orderedIDs: [String]
    ) {
        var result: [String] = []
        var seen = Set<String>()

        for id in orderedIDs {
            guard
                favorites.contains(id),
                seen.insert(id).inserted
            else {
                continue
            }

            result.append(id)
        }

        // Ontbrekende favorieten achteraan behouden.
        for row in favoriteRows {
            guard
                !seen.contains(row.id)
            else {
                continue
            }

            result.append(
                row.id
            )

            seen.insert(
                row.id
            )
        }

        favoriteOrder =
            result

        saveFavoriteOrder()
    }

    // MARK: tvOS ordering

    func moveFavoriteUp(
        _ row: VeyraGuideChannel
    ) {
        guard
            let index =
                favoriteOrder
                    .firstIndex(
                        of: row.id
                    ),
            index > 0
        else {
            return
        }

        favoriteOrder.swapAt(
            index,
            index - 1
        )

        saveFavoriteOrder()
    }

    func moveFavoriteDown(
        _ row: VeyraGuideChannel
    ) {
        guard
            let index =
                favoriteOrder
                    .firstIndex(
                        of: row.id
                    ),
            index < favoriteOrder.count - 1
        else {
            return
        }

        favoriteOrder.swapAt(
            index,
            index + 1
        )

        saveFavoriteOrder()
    }

    func moveFavoriteToTop(
        _ row: VeyraGuideChannel
    ) {
        guard
            let index =
                favoriteOrder
                    .firstIndex(
                        of: row.id
                    ),
            index > 0
        else {
            return
        }

        favoriteOrder.remove(
            at: index
        )

        favoriteOrder.insert(
            row.id,
            at: 0
        )

        saveFavoriteOrder()
    }

    func moveFavoriteToBottom(
        _ row: VeyraGuideChannel
    ) {
        guard
            let index =
                favoriteOrder
                    .firstIndex(
                        of: row.id
                    ),
            index < favoriteOrder.count - 1
        else {
            return
        }

        favoriteOrder.remove(
            at: index
        )

        favoriteOrder.append(
            row.id
        )

        saveFavoriteOrder()
    }

    func canMoveFavoriteUp(
        _ row: VeyraGuideChannel
    ) -> Bool {
        guard
            let index =
                favoriteOrder
                    .firstIndex(
                        of: row.id
                    )
        else {
            return false
        }

        return index > 0
    }

    func canMoveFavoriteDown(
        _ row: VeyraGuideChannel
    ) -> Bool {
        guard
            let index =
                favoriteOrder
                    .firstIndex(
                        of: row.id
                    )
        else {
            return false
        }

        return index
            < favoriteOrder.count - 1
    }

    // MARK: - EPG

    private func loadGuide(
        configuration: IPTVStoredConfiguration,
        token: UUID,
        useCachedGuide: Bool = false
    ) async {
        if useCachedGuide { return }
        // Gebruik `allChannels` (ongefilterd door Live TV-zichtbaarheid) i.p.v.
        // `channels`, zodat de EPG-programmadata ook beschikbaar is voor niet-
        // zichtbaar-gezette zenders (nodig voor sportwedstrijd-kanaalmatching).
        // Dit kost geen extra netwerkverkeer: `epgService.load` downloadt
        // altijd het volledige XMLTV-bestand van de provider en gebruikt
        // `channelIDs` alleen als lokaal filter tijdens het parsen — een
        // grotere set kost dus enkel wat extra parse-/geheugengebruik, geen
        // extra download.
        let ids = Set(
            allChannels
                .compactMap {
                    $0.channel.tvgID?
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                }
                .filter {
                    !$0.isEmpty
                }
        )

        guard !ids.isEmpty else {
            guideMessage =
                "Geen van de providerzenders heeft een EPG-ID. Kijk live blijft beschikbaar."

            return
        }

        loadingGuide = true

        defer {
            if generation == token {
                loadingGuide = false
            }
        }

        do {
            let source: URL

            switch configuration {
            case .xtream(let value):
                let base =
                    value.serverURL
                        .appendingPathComponent(
                            "xmltv.php"
                        )

                guard
                    var parts =
                        URLComponents(
                            url: base,
                            resolvingAgainstBaseURL:
                                false
                        )
                else {
                    throw VeyraEPGError.invalidURL
                }

                parts.queryItems = [
                    URLQueryItem(
                        name: "username",
                        value: value.username
                    ),
                    URLQueryItem(
                        name: "password",
                        value: value.password
                    )
                ]

                guard
                    let url = parts.url
                else {
                    throw VeyraEPGError.invalidURL
                }

                source = url

            case .m3u(let value):
                source =
                    try await epgService
                        .discoverSource(
                            in: value.playlistURL
                        )
            }

            try Task.checkCancellation()

            let today =
                Calendar.current
                    .startOfDay(
                        for: Date()
                    )

            let from =
                today.addingTimeInterval(
                    -86_400
                )

            let to =
                today.addingTimeInterval(
                    8 * 86_400
                )

            let result =
                try await epgService.load(
                    url: source,
                    channelIDs: ids,
                    from: from,
                    to: to
                )

            try Task.checkCancellation()

            guard generation == token else {
                return
            }

            programmeIndex =
                result.programmes

            // Nieuw geladen EPG-venster: kijk of er nieuwe afleveringen bij
            // zijn voor een actieve "neem hele serie op"-regel. Bewust niet
            // bij het herstellen van de cache hierboven — alleen bij vers
            // opgehaalde data kunnen er echt nieuwe afleveringen bij zitten.
            let scanChannels = channels
            Task { await VeyraHubRecorderScheduler.scheduleUpcomingEpisodes(
                programmeIndex: result.programmes, channels: scanChannels
            ) }

            IPTVDiskCache.write(
                result.programmes,
                key: "live-guide-v1-\(configuration.providerIdentifier)"
            )

            let linked =
                channels.filter {
                    !programmes(
                        for: $0
                    )
                    .isEmpty
                }
                .count

            var message =
                "Gids voor \(linked) van \(channels.count) zichtbare zenders."

            if result.skipped > 0 {
                message +=
                    " \(result.skipped) onvolledige uitzendingen overgeslagen."
            }

            guideMessage =
                message

        } catch {
            guard
                generation == token,
                !Task.isCancelled
            else {
                return
            }

            if let error =
                error as? VeyraEPGError
            {
                guideMessage =
                    error.localizedDescription

            } else {
                guideMessage =
                    "De EPG kon niet worden opgehaald. Controleer je provider en probeer Vernieuwen. Kijk live blijft beschikbaar."
            }
        }
    }

    // MARK: - Playback

    func play(
        _ row: VeyraGuideChannel
    ) -> PlayableSource {
        recent.removeAll {
            $0 == row.id
        }

        recent.insert(
            row.id,
            at: 0
        )

        recent =
            Array(
                recent.prefix(
                    40
                )
            )

        UserDefaults.standard.set(
            recent,
            forKey: recentKey
        )

        return PlayableSource(
            name: ChannelNameOverrideStore.effectiveName(
                channelID: row.channel.id, defaultName: row.channel.name
            ),
            description: row.channel.group,
            url: row.channel.streamURL,
            kind: .liveTV,
            providerName: providerName,
            epgChannelID: row.channel.tvgID,
            epgProgrammes: Array(programmes(for: row)
                .filter { $0.end > Date() }
                .prefix(12))
        )
    }

    // MARK: - Timeline

    func moveWindow(
        _ hours: Int
    ) {
        let candidate =
            windowStart
                .addingTimeInterval(
                    Double(hours)
                    * 3_600
                )

        let today =
            Calendar.current
                .startOfDay(
                    for: Date()
                )

        windowStart =
            max(
                today.addingTimeInterval(
                    -86_400
                ),
                min(
                    candidate,
                    today.addingTimeInterval(
                        7 * 86_400
                    )
                )
            )
    }

    func showNow() {
        windowStart =
            Self.currentWindow()
    }

    // MARK: - Local storage keys

    private var favoritesKey: String {
        "veyra.epg.favorites.\(providerKey ?? "none")"
    }

    private var favoriteOrderKey: String {
        "veyra.epg.favoriteOrder.\(providerKey ?? "none")"
    }

    private var recentKey: String {
        "veyra.epg.recent.\(providerKey ?? "none")"
    }


    // MARK: - Date

    private static func currentWindow() -> Date {
        let now = Date()

        let minute =
            Calendar.current
                .component(
                    .minute,
                    from: now
                )

        let hour =
            Calendar.current
                .dateInterval(
                    of: .hour,
                    for: now
                )?
                .start
            ?? now

        return hour.addingTimeInterval(
            Double(
                minute / 30
            )
            * 1_800
            - 1_800
        )
    }

    // MARK: - Clear

    private func clear() {
        channels = []
        categories = []
        programmeIndex = [:]

        favorites = []
        favoriteOrder = []
        recent = []

        loadingChannels = false
        loadingGuide = false

        providerKey = nil

        guideMessage = nil

        completedReloadID = nil
        loadedAt = nil
        loadedConfiguration = nil
        loadedPreferences = nil

        selectedCategory = "favorites"
    }
}

nonisolated
struct VeyraEPGSlot:
    Identifiable,
    Sendable
{
    let start: Date
    let end: Date
    let programme: VeyraEPGProgramme?

    var id: String {
        "\(start.timeIntervalSince1970)|\(programme?.id ?? "gap")"
    }

    static func make(
        _ programmes: [VeyraEPGProgramme],
        from: Date,
        to: Date
    ) -> [Self] {
        var cursor = from
        var result: [Self] = []

        for programme
            in programmes
            where programme.end > from
            && programme.start < to
        {
            let start =
                max(
                    cursor,
                    programme.start
                )

            let end =
                min(
                    to,
                    programme.end
                )

            guard end > start else {
                continue
            }

            if start > cursor {
                result.append(
                    Self(
                        start: cursor,
                        end: start,
                        programme: nil
                    )
                )
            }

            result.append(
                Self(
                    start: start,
                    end: end,
                    programme: programme
                )
            )

            cursor = end

            if cursor >= to {
                break
            }
        }

        if cursor < to {
            result.append(
                Self(
                    start: cursor,
                    end: to,
                    programme: nil
                )
            )
        }

        return result
    }
}
