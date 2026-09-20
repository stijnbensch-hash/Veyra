import Foundation
import Combine
import CryptoKit

nonisolated struct VeyraGuideChannel: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let channel: IPTVChannel
    let categoryID: String
}

@MainActor
final class VeyraEPGStore: ObservableObject {
    @Published private(set) var channels: [VeyraGuideChannel] = []
    @Published private(set) var categories: [IPTVCategory] = []
    @Published private(set) var providers: [IPTVStoredProvider] = []
    @Published private(set) var activeProviderID: UUID?

    @Published private(set) var programmeIndex:
        [String: [VeyraEPGProgramme]] = [:]

    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var recent: [String] = []

    @Published private(set) var loadingChannels = false
    @Published private(set) var loadingGuide = false

    @Published private(set) var channelError: String?
    @Published private(set) var guideMessage: String?

    @Published var selectedCategory = "all"
    @Published var searchText = ""
    @Published var reloadID = UUID()
    @Published var windowStart = VeyraEPGStore.currentWindow()

    let windowDuration: TimeInterval = 3 * 3_600

    private let service = IPTVService()
    private let configStore = IPTVConfigurationStore()
    private let preferencesStore = IPTVProviderPreferencesStore()
    private let epgService = VeyraEPGService()

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

    var visibleChannels: [VeyraGuideChannel] {
        var values = channels

        switch selectedCategory {
        case "favorites":
            values = values.filter {
                favorites.contains($0.id)
            }

        case "recent":
            let order = Dictionary(
                uniqueKeysWithValues: recent.enumerated().map {
                    ($1, $0)
                }
            )

            values = values.filter {
                order[$0.id] != nil
            }
            .sorted {
                (order[$0.id] ?? 0) < (order[$1.id] ?? 0)
            }

        case "all":
            break

        default:
            values = values.filter {
                "group:" + $0.categoryID == selectedCategory
            }
        }

        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if !query.isEmpty {
            values = values.filter { row in
                row.channel.name.localizedCaseInsensitiveContains(query)
                    || programmes(for: row).contains {
                        $0.start < windowEnd
                            && $0.end > windowStart
                            && (
                                $0.title.localizedCaseInsensitiveContains(query)
                                    || $0.subtitle.localizedCaseInsensitiveContains(query)
                            )
                    }
            }
        }

        return values
    }

    func programmes(
        for row: VeyraGuideChannel
    ) -> [VeyraEPGProgramme] {
        let id = row.channel.tvgID?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

        return programmeIndex[id] ?? []
    }

    func reload() async {
        let token = UUID()
        generation = token

        let requestedReloadID = reloadID

        do {
            providers = try configStore.loadProviders()
            activeProviderID = try configStore.activeProviderID()

            guard let configuration = try configStore.load() else {
                clear()

                channelError =
                    "Geen IPTV-provider ingesteld. Voeg een provider toe via Instellingen > Bronnen > IPTV."

                return
            }

            let preferences = preferencesStore.load(
                for: configuration
            )

            // Na terugkeer uit de speler niet telkens
            // de volledige feed downloaden.
            if completedReloadID == requestedReloadID,
               configuration == loadedConfiguration,
               preferences == loadedPreferences,
               let loadedAt,
               Date().timeIntervalSince(loadedAt) < 900 {
                return
            }

            let changedProvider =
                providerKey != configuration.providerIdentifier

            providerKey = configuration.providerIdentifier

            let channelsCacheKey =
                "liveTV.channels.\(configuration.providerIdentifier)"

            let categoriesCacheKey =
                "liveTV.categories.\(configuration.providerIdentifier)"

            let epgCacheKey =
                "liveTV.epg.\(configuration.providerIdentifier)"

            channelError = nil
            guideMessage = nil

            favorites = Set(
                UserDefaults.standard.stringArray(
                    forKey: favoritesKey
                ) ?? []
            )

            recent = Array(
                (
                    UserDefaults.standard.stringArray(
                        forKey: recentKey
                    ) ?? []
                )
                .prefix(40)
            )

            if changedProvider {
                selectedCategory = "all"
                searchText = ""
                windowStart = Self.currentWindow()
                channels = []
                categories = []
                programmeIndex = [:]
            }

            // Toon de vorige zenderlijst en gids meteen (uit cache) terwijl
            // op de achtergrond wordt ververst, zodat er geen wachttijd is.
            if channels.isEmpty,
               let cachedChannels =
                IPTVDiskCache.read(
                    [VeyraGuideChannel].self,
                    key: channelsCacheKey
                )?.value,
               let cachedCategories =
                IPTVDiskCache.read(
                    [IPTVCategory].self,
                    key: categoriesCacheKey
                )?.value {
                channels = cachedChannels
                categories = cachedCategories
            }

            if programmeIndex.isEmpty,
               let cachedProgrammes =
                IPTVDiskCache.read(
                    [String: [VeyraEPGProgramme]].self,
                    key: epgCacheKey
                )?.value {
                programmeIndex = cachedProgrammes
            }

            loadingChannels = channels.isEmpty
            loadingGuide = false

            let receivedChannels: [IPTVChannel]
            var receivedCategories: [IPTVCategory]

            switch configuration {
            case .xtream(let value):
                receivedCategories =
                    try await service.loadXtreamLiveCategories(
                        configuration: value
                    )

                try Task.checkCancellation()

                receivedChannels =
                    try await service.loadXtreamLiveChannels(
                        configuration: value
                    )

            case .m3u(let value):
                receivedChannels =
                    try await service.loadM3UChannels(
                        configuration: value
                    )

                let names = Set(
                    receivedChannels.map(
                        \.iptvPreferenceGroupName
                    )
                )

                receivedCategories = names.sorted().map {
                    IPTVCategory(
                        id: IPTVChannel.iptvPreferenceGroupID($0),
                        name: $0,
                        contentType: .live
                    )
                }
            }

            try Task.checkCancellation()

            guard generation == token else {
                return
            }

            var seen = Set<String>()
            var rows: [VeyraGuideChannel] = []

            for channel in receivedChannels
                where channel.contentType == .live {
                let groupID: String

                switch configuration {
                case .m3u:
                    groupID = IPTVChannel.iptvPreferenceGroupID(
                        channel.iptvPreferenceGroupName
                    )

                case .xtream:
                    groupID = channel.group ?? ""
                }

                guard
                    preferences.isLiveCategoryVisible(groupID),
                    preferences.isLiveChannelVisible(channel.id)
                else {
                    continue
                }

                // M3U kan dezelfde tvg-id voor HD/SD-varianten gebruiken.
                let identity = channel.sourceType == .m3u
                    ? "\(channel.id)|\(channel.streamURL.absoluteString)"
                    : channel.id

                let id = SHA256.hash(
                    data: Data(identity.utf8)
                )
                .map {
                    String(format: "%02x", $0)
                }
                .joined()

                if seen.insert(id).inserted {
                    rows.append(
                        VeyraGuideChannel(
                            id: id,
                            channel: channel,
                            categoryID: groupID
                        )
                    )
                }
            }

            channels = rows

            let groupsWithChannels = Set(
                rows.map(\.categoryID)
            )

            var seenGroups = Set<String>()

            receivedCategories = receivedCategories.filter {
                preferences.isLiveCategoryVisible($0.id)
                    && groupsWithChannels.contains($0.id)
                    && seenGroups.insert($0.id).inserted
            }

            categories = receivedCategories.sorted {
                $0.name.localizedStandardCompare($1.name)
                    == .orderedAscending
            }

            if selectedCategory.hasPrefix("group:"),
               !categories.contains(
                where: {
                    "group:" + $0.id == selectedCategory
                }
               ) {
                selectedCategory = "all"
            }

            loadingChannels = false
            loadedConfiguration = configuration
            loadedPreferences = preferences

            IPTVDiskCache.write(
                channels,
                key: channelsCacheKey
            )

            IPTVDiskCache.write(
                categories,
                key: categoriesCacheKey
            )

            await loadGuide(
                configuration: configuration,
                token: token,
                cacheKey: epgCacheKey
            )

            guard
                generation == token,
                !Task.isCancelled
            else {
                return
            }

            completedReloadID = requestedReloadID
            loadedAt = Date()
        } catch {
            guard generation == token else {
                return
            }

            loadingChannels = false
            loadingGuide = false

            if !Task.isCancelled {
                // Bij een fout blijft eerder geladen (gecachte) inhoud
                // zichtbaar in plaats van een foutmelding te tonen.
                guard channels.isEmpty else {
                    return
                }

                if let failure = error as? IPTVServiceError {
                    channelError = failure.localizedDescription
                } else if let failure = error as? XtreamError {
                    channelError = failure.localizedDescription
                } else {
                    channelError =
                        "De providers of zenders konden niet worden geladen. Controleer de verbinding en kies Vernieuwen."
                }
            }
        }
    }

    private func loadGuide(
        configuration: IPTVStoredConfiguration,
        token: UUID,
        cacheKey: String
    ) async {
        let ids = Set(
            channels.compactMap {
                $0.channel.tvgID?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
        )

        guard !ids.isEmpty else {
            guideMessage =
                "De zichtbare zenders hebben geen EPG-ID. Kijk live blijft beschikbaar."

            return
        }

        loadingGuide = programmeIndex.isEmpty

        defer {
            if generation == token {
                loadingGuide = false
            }
        }

        do {
            let source: URL

            switch configuration {
            case .xtream(let value):
                let base = value.serverURL
                    .appendingPathComponent("xmltv.php")

                guard var parts = URLComponents(
                    url: base,
                    resolvingAgainstBaseURL: false
                ) else {
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

                guard let url = parts.url else {
                    throw VeyraEPGError.invalidURL
                }

                source = url

            case .m3u(let value):
                source = try await epgService.discoverSource(
                    in: value.playlistURL
                )
            }

            try Task.checkCancellation()

            let today = Calendar.current.startOfDay(
                for: Date()
            )

            let from = today.addingTimeInterval(-86_400)
            let to = today.addingTimeInterval(8 * 86_400)

            let result = try await epgService.load(
                url: source,
                channelIDs: ids,
                from: from,
                to: to
            )

            try Task.checkCancellation()

            guard generation == token else {
                return
            }

            programmeIndex = result.programmes

            IPTVDiskCache.write(
                result.programmes,
                key: cacheKey
            )

            let linked = channels.filter {
                !programmes(for: $0).isEmpty
            }
            .count

            var message =
                "Gids voor \(linked) van \(channels.count) zichtbare zenders."

            if result.skipped > 0 {
                message +=
                    " \(result.skipped) onvolledige uitzendingen overgeslagen."
            }

            guideMessage = message
        } catch {
            guard
                generation == token,
                !Task.isCancelled
            else {
                return
            }

            // Bij een fout blijft een eerder gecachte gids zichtbaar
            // in plaats van een foutmelding te tonen.
            guard programmeIndex.isEmpty else {
                return
            }

            if let error = error as? VeyraEPGError {
                guideMessage = error.localizedDescription
            } else {
                // Netwerkfouten kunnen URL's met toegangsgegevens bevatten.
                guideMessage =
                    "De EPG kon niet worden opgehaald. Controleer je provider en probeer Vernieuwen. Kijk live blijft beschikbaar."
            }
        }
    }

    func selectProvider(
        _ provider: IPTVStoredProvider
    ) {
        do {
            try configStore.setActiveProvider(
                id: provider.id
            )

            NotificationCenter.default.post(
                name: .iptvConfigurationDidChange,
                object: nil
            )
        } catch {
            channelError = error.localizedDescription
        }
    }

    func toggleFavorite(
        _ row: VeyraGuideChannel
    ) {
        guard providerKey != nil else {
            return
        }

        if favorites.contains(row.id) {
            favorites.remove(row.id)
        } else {
            favorites.insert(row.id)
        }

        UserDefaults.standard.set(
            Array(favorites),
            forKey: favoritesKey
        )
    }

    func play(
        _ row: VeyraGuideChannel
    ) -> PlayableSource {
        recent.removeAll {
            $0 == row.id
        }

        recent.insert(row.id, at: 0)
        recent = Array(recent.prefix(40))

        UserDefaults.standard.set(
            recent,
            forKey: recentKey
        )

        return service.playableSource(
            for: row.channel
        )
    }

    func moveWindow(_ hours: Int) {
        let candidate = windowStart.addingTimeInterval(
            Double(hours) * 3_600
        )

        let today = Calendar.current.startOfDay(
            for: Date()
        )

        windowStart = max(
            today.addingTimeInterval(-86_400),
            min(
                candidate,
                today.addingTimeInterval(7 * 86_400)
            )
        )
    }

    func showNow() {
        windowStart = Self.currentWindow()
    }

    private var favoritesKey: String {
        "veyra.epg.favorites.\(providerKey ?? "none")"
    }

    private var recentKey: String {
        "veyra.epg.recent.\(providerKey ?? "none")"
    }

    private static func currentWindow() -> Date {
        let now = Date()
        let minute = Calendar.current.component(
            .minute,
            from: now
        )

        let hour = Calendar.current.dateInterval(
            of: .hour,
            for: now
        )?.start ?? now

        return hour.addingTimeInterval(
            Double(minute / 30) * 1_800 - 1_800
        )
    }

    private func clear() {
        channels = []
        categories = []
        programmeIndex = [:]
        favorites = []
        recent = []

        loadingChannels = false
        loadingGuide = false

        providerKey = nil
        guideMessage = nil
        completedReloadID = nil
        loadedAt = nil
        loadedConfiguration = nil
        loadedPreferences = nil
    }
}

// MARK: - Tijdlijnindeling

nonisolated struct VeyraEPGSlot: Identifiable, Sendable {
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

        for programme in programmes
            where programme.end > from && programme.start < to {
            let start = max(cursor, programme.start)
            let end = min(to, programme.end)

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
