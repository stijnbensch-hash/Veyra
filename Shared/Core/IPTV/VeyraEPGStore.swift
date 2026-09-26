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
    /// >= 1 MB wordt weggeschreven ("byte count limit reached"). De
    /// catalogus- en gidssnapshots hieronder kunnen met veel zenders/dagen
    /// aan programmadata makkelijk over die grens gaan. Ruim onder de
    /// grens blijven (i.p.v. precies op 1 MB toetsen) voorkomt dat een
    /// snapshot net op het randje alsnog crasht. `IPTVDiskCache` (los
    /// bestand, geen CFPreferences-limiet) blijft in dat geval de
    /// betrouwbare cache — deze snapshot in UserDefaults is alleen een
    /// extra kopie voor snelle herstart en voor VeyraHubSyncService.
    private static let maxUserDefaultsSnapshotBytes = 900_000

    private func isSafeForUserDefaults(_ data: Data) -> Bool {
        data.count < Self.maxUserDefaultsSnapshotBytes
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

    func reload() async {
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
            if completedReloadID == requestedReloadID,
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
            if let cached = IPTVDiskCache.read(
                VeyraLiveCatalog.self, key: cacheKey
            )?.value {
                applyCatalog(cached, configuration: configuration, preferences: preferences)
                loadingChannels = false
            }
            if let data = UserDefaults.standard.data(
                forKey: VeyraIPTVSnapshot.catalogPrefix + configuration.providerIdentifier
            ), let snapshot = VeyraIPTVSnapshot.decode(
                VeyraCatalogSnapshot.self, from: data
            ) {
                applyCatalog(snapshot.catalog, configuration: configuration, preferences: preferences)
                loadingChannels = false
            }
            let guideCacheKey = "live-guide-v1-\(configuration.providerIdentifier)"
            if let cachedGuide = IPTVDiskCache.read(
                [String: [VeyraEPGProgramme]].self,
                key: guideCacheKey
            )?.value {
                programmeIndex = cachedGuide
            }
            if let data = UserDefaults.standard.data(
                forKey: VeyraIPTVSnapshot.guidePrefix + configuration.providerIdentifier
            ), let snapshot = VeyraIPTVSnapshot.decode(
                VeyraGuideSnapshot.self, from: data
            ) {
                programmeIndex = snapshot.programmes
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
            let visibleCatalog = VeyraLiveCatalog(
                channels: channels.map(\.channel),
                categories: categories
            )
            if let snapshot = VeyraIPTVSnapshot.encode(
                VeyraCatalogSnapshot(savedAt: Date(), catalog: visibleCatalog)
            ), isSafeForUserDefaults(snapshot) {
                UserDefaults.standard.set(
                    snapshot,
                    forKey: VeyraIPTVSnapshot.catalogPrefix + configuration.providerIdentifier
                )
            }

            loadingChannels = false

            loadedConfiguration = configuration
            loadedPreferences = preferences

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
        token: UUID
    ) async {
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
            if let snapshot = VeyraIPTVSnapshot.encode(
                VeyraGuideSnapshot(savedAt: Date(), programmes: result.programmes)
            ), isSafeForUserDefaults(snapshot) {
                UserDefaults.standard.set(
                    snapshot,
                    forKey: VeyraIPTVSnapshot.guidePrefix + configuration.providerIdentifier
                )
            }

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

        return service.playableSource(
            for: row.channel
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
