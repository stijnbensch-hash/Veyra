import Foundation

/// Syncs Veyra's settings, shelves/hero, source order, and addons across
/// devices through the connected VeyraHub media-server session — the
/// replacement for the old iCloud key-value sync (`CloudSettingsSync`,
/// removed). The local stores remain the UI's cache.
@MainActor
final class VeyraHubSyncService {
    static let shared = VeyraHubSyncService()
    private(set) var isActive = false

    // MARK: - Synced keys
    //
    // Dit is de volledige lijst instellingen die via VeyraHub meegaan
    // tussen apparaten (voorheen via iCloud's sleutel-waardeopslag).
    // Bewust NIET gesynchroniseerd: `AddonMigration`'s eenmalige
    // migratievlag, `JellyfinClient.persistentDeviceID()` (per-installatie
    // apparaat-ID) en `ChannelLogoOverrideStore`'s bestandsverwijzingen
    // (zie hieronder, die gaan via hun eigen "livetv"-document mee).

    private static let simpleKeys: [String] = [
        // Afspelen — zie Shared/Theme/PlaybackSettings.swift
        "playback.autoRotateLandscape", "playback.autoPlayNextEpisode",
        "playback.autoSelectFirstSource", "playback.skipContinueWatchingDetails",
        "playback.preferredResolution", "playback.cellularResolution",
        "playback.hideProgressBar", "playback.audioLanguage",
        "playback.audioFallbackLanguage", "playback.subtitleLanguage",
        "playback.subtitleFallbackLanguage", "playback.autoSelectSubtitles",
        "playback.animeAudio", "playback.showSkipIntroButton", "playback.autoSkipIntro",
        "playback.showSkipRecapButton", "playback.showSkipCreditsButton",
        "playback.postCreditsAlert", "playback.autoPlayNextCountdownEnabled",
        "playback.countdownDuration", "playback.selectedPlayer",
    ]

    private static let iptvDisplayKeys: [String] = [
        // IPTV-weergave — zie Shared/Theme/IPTVPlaybackSettings.swift
        "iptv.guideTheme", "iptv.hideCountryPrefix", "iptv.playerEngine",
        "iptv.bufferDuration", "iptv.catchUpOffsetMode", "iptv.catchUpOffsetManualSeconds",
        "iptv.refreshChannelsInterval", "iptv.refreshEPGInterval", "iptv.showFPSCounter",
    ]

    private static let subtitleKeys: [String] = [
        // Ondertitels — zie Shared/Theme/SubtitleAppearanceSettings.swift
        "veyra.subtitle.size", "veyra.subtitle.position", "veyra.subtitle.background",
        "veyra.subtitle.shadow", "veyra.subtitle.offset",
    ]

    private static let generalKeys: [String] = [
        // Algemeen — zie Shared/Theme/GeneralSettings.swift
        "general.showContinueWatching", "general.continueWatchingLimit",
        "general.hideContinueWatchingReleaseDate", "general.showUpcoming",
        "general.includeWatchlistPremieresInUpcoming", "general.showReleaseYear",
        "general.hideTitlesUnderPosters", "general.hideEpisodesRemaining",
        "general.hideScoreSpoilers", "general.chooseChannelOnTap", "general.textSize",
        // Posterverrijking — zie Shared/Theme/PosterEnrichmentSettings.swift
        "posterEnrichment.mode", "posterEnrichment.showGenre", "posterEnrichment.showRating",
        "posterEnrichment.ratingSource", "posterEnrichment.showAgeRating",
        "posterEnrichment.showQualityLabels", "posterEnrichment.showTrendLabels",
        "posterEnrichment.showEpisodesRemaining",
        // Overig
        "catalog.watchRegion", "openSubtitlesEnabled", "metadata.source.preference",
        "sports.favoriteTeams",
    ]

    private static var simpleKeysAll: [String] {
        simpleKeys + iptvDisplayKeys + subtitleKeys + generalKeys
    }

    private static let shelfHeroDataKeys: [String] = [
        "veyra.shelves.configured",
        // Home: filmcollecties en streamingdiensten (volgorde, namen, banners/logo's als https-adres)
        "veyra.bento.collections", "veyra.bento.streaming", "veyra.home.layout", "veyra.home.presetChosen",
    ]

    private static let sourceOrderDataKeys: [String] = [
        "sourceOrder.categoryOrder", "sourceOrder.iptvProviderOrder",
    ]

    private static let addonDataKeys: [String] = [
        "veyra.addons.installed",
    ]

    private static var settingsDataKeys: [String] {
        shelfHeroDataKeys + sourceOrderDataKeys + addonDataKeys
    }

    private static let metadataPrefix = "metadata.rating."
    private static let iptvVisibilityPrefix = "veyra.iptv.provider.preferences."
    private static let settingsDynamicPrefixes: [String] = [metadataPrefix, iptvVisibilityPrefix]

    private static func isSettingsKey(_ key: String) -> Bool {
        simpleKeysAll.contains(key) || settingsDataKeys.contains(key) ||
        settingsDynamicPrefixes.contains { key.hasPrefix($0) }
    }

    /// `UserDefaults`/`CFPreferences` crasht hard op tvOS zodra één sleutel
    /// >= 1 MB wordt weggeschreven ("byte count limit reached"). Een
    /// waarde die van de Hub binnenkomt (bv. een grote EPG-gids) kan die
    /// grens overschrijden — dan gewoon lokaal niet toepassen in plaats
    /// van de app te laten crashen; de volgende sync probeert het opnieuw.
    private static let maxLocalWriteBytes = 900_000

    private func isSafeForLocalWrite(_ data: Data) -> Bool {
        data.count < Self.maxLocalWriteBytes
    }

    private let defaults = UserDefaults.standard
    private var started = false
    private var running = false
    private var scheduled: Task<Void, Never>?
    private var scheduledAt: Date?
    private var baseline: [String: [String: String]] = [:]
    private var activeAccountID: UUID?

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed),
            name: UserDefaults.didChangeNotification, object: defaults)
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed),
            name: .veyraMediaServerConfigurationDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed),
            name: .channelOverrideChanged, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed),
            name: .iptvConfigurationDidChange, object: nil)
        schedule(after: 0)
    }

    @objc private func changed() { schedule(after: 1) }

    private func schedule(after seconds: TimeInterval) {
        if running { return }
        let fireAt = Date().addingTimeInterval(seconds)
        if let scheduledAt, scheduledAt <= fireAt { return }
        scheduled?.cancel()
        scheduledAt = fireAt
        scheduled = Task { [weak self] in
            if seconds > 0 {
                try? await Task.sleep(for: .seconds(seconds))
            }
            guard !Task.isCancelled else { return }
            self?.scheduled = nil
            self?.scheduledAt = nil
            await self?.sync()
        }
    }

    private func sync() async {
        guard !running else { return }
        running = true
        defer {
            running = false
            schedule(after: 30)
        }

        // Only a Hub account answers this endpoint. Ordinary Jellyfin servers
        // are left alone, and no second sign-in is requested.
        let accounts = MediaServerStore().load()
        if let activeAccountID, !accounts.contains(where: { $0.id == activeAccountID }) {
            self.activeAccountID = nil
            isActive = false
        }
        for account in accounts where account.kind == .jellyfin {
            do {
                let settings = try await get("settings", account: account)
                let liveTV = try await get("livetv", account: account)
                isActive = true
                activeAccountID = account.id
                try await reconcile("settings", remote: settings, account: account)
                try await reconcile("livetv", remote: liveTV, account: account)
                return
            } catch {
                continue
            }
        }
    }

    private struct Document {
        var version: Int
        var data: [String: Any]
        var values: [String: String] {
            data["values"] as? [String: String] ?? [:]
        }
    }

    private func endpoint(_ name: String, account: MediaServerAccount) -> URL {
        account.serverURL.appendingPathComponent("veyra/v1/\(name)")
    }

    private func get(_ name: String, account: MediaServerAccount) async throws -> Document {
        var request = URLRequest(url: endpoint(name, account: account))
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = object["version"] as? Int,
              let content = object["data"] as? [String: Any]
        else { throw URLError(.badServerResponse) }
        return Document(version: version, data: content)
    }

    private func put(_ name: String, account: MediaServerAccount,
                     baseVersion: Int, data: [String: Any]) async throws -> Bool {
        var request = URLRequest(url: endpoint(name, account: account))
        request.httpMethod = "PUT"
        request.timeoutInterval = 10
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "baseVersion": baseVersion, "data": data
        ])
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode
        if status == 409 { return false } // Retry after fetching the new version.
        guard status == 200 else { throw URLError(.badServerResponse) }
        return true
    }

    private func reconcile(_ name: String, remote: Document,
                           account: MediaServerAccount) async throws {
        let id = "\(account.id.uuidString):\(name)"
        let local = snapshot(name)
        let old = baseline[id]
        let incoming = remote.values
        var merged = incoming

        if let old {
            // Preserve edits to different keys on both devices. When the same
            // key changed twice, the newer Hub value wins.
            for (key, value) in local where key != ChannelLogoOverrideStore.key &&
                    old[key] != value && old[key] == incoming[key] {
                merged[key] = value
            }
        } else if remote.version == 0 || incoming.isEmpty {
            merged.merge(local) { _, localValue in localValue }
        } else {
            // On first connection the Hub is authoritative, but add local
            // keys the Hub has never seen (iCloud migration).
            for (key, value) in local where merged[key] == nil { merged[key] = value }
        }

        if name == "livetv",
           let logoValue = mergeLogoOverrides(local: local[ChannelLogoOverrideStore.key],
                                              old: old?[ChannelLogoOverrideStore.key],
                                              remote: incoming[ChannelLogoOverrideStore.key]) {
            merged[ChannelLogoOverrideStore.key] = logoValue
        }

        apply(merged, name: name)
        if merged != incoming {
            var body = remote.data
            body["values"] = merged
            guard try await put(name, account: account,
                                baseVersion: remote.version, data: body) else { return }
        }
        baseline[id] = merged
    }

    private func keys(_ name: String) -> [String] {
        if name == "settings" {
            let fixed = Self.simpleKeysAll + Self.settingsDataKeys
            let dynamic = defaults.dictionaryRepresentation().keys.filter { key in
                Self.settingsDynamicPrefixes.contains { key.hasPrefix($0) }
            }
            return Array(Set(fixed + dynamic))
        }
        return defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix("veyra.epg.favorites.") ||
            $0.hasPrefix("veyra.epg.favoriteOrder.") ||
            $0.hasPrefix("veyra.epg.recent.") ||
            $0.hasPrefix(VeyraIPTVSnapshot.catalogPrefix) ||
            $0.hasPrefix(VeyraIPTVSnapshot.guidePrefix) ||
            $0 == "veyra.channelNameOverrides" ||
            $0 == ChannelLogoOverrideStore.key
        }
    }

    private func snapshot(_ name: String) -> [String: String] {
        var result: [String: String] = [:]
        for key in keys(name) {
            let value: Any?
            if key == ChannelLogoOverrideStore.key {
                let urls = ChannelLogoOverrideStore.all().filter { _, raw in
                    guard let scheme = URL(string: raw)?.scheme?.lowercased() else { return false }
                    return scheme == "https" || scheme == "http"
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                value = try? encoder.encode(urls)
            } else {
                value = defaults.object(forKey: key)
            }
            guard let value,
                  let encoded = try? PropertyListSerialization.data(
                    fromPropertyList: value, format: .binary, options: 0)
            else { continue }
            result[key] = encoded.base64EncodedString()
        }
        if name == "settings", let credentials = try? IPTVConfigurationStore().exportForHub() {
            result["veyra.iptv.providers"] = credentials.base64EncodedString()
        }
        return result
    }

    private func apply(_ values: [String: String], name: String) {
        var changed = false
        var iptvChanged = false
        for (key, encoded) in values {
            if name == "settings", key == "veyra.iptv.providers" {
                guard let data = Data(base64Encoded: encoded) else { continue }
                if let local = try? IPTVConfigurationStore().exportForHub(),
                   sameJSON(local, data) { continue }
                do {
                    try IPTVConfigurationStore().importFromHub(data)
                    changed = true
                    iptvChanged = true
                } catch { }
                continue
            }
            if name == "livetv", key == ChannelLogoOverrideStore.key {
                guard let remote = decodeLogoOverrides(encoded) else { continue }
                let localFiles = ChannelLogoOverrideStore.all().filter { _, raw in
                    URL(string: raw)?.isFileURL == true
                }
                let desired = remote.merging(localFiles) { _, local in local }
                guard desired != ChannelLogoOverrideStore.all() else { continue }
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                guard let data = try? encoder.encode(desired), isSafeForLocalWrite(data) else { continue }
                defaults.set(data, forKey: key)
                changed = true
                continue
            }
            guard (name == "settings" ? Self.isSettingsKey(key) :
                    key.hasPrefix("veyra.epg.favorites.") ||
                    key.hasPrefix("veyra.epg.favoriteOrder.") ||
                    key.hasPrefix("veyra.epg.recent.") ||
                    key.hasPrefix(VeyraIPTVSnapshot.catalogPrefix) ||
                    key.hasPrefix(VeyraIPTVSnapshot.guidePrefix) ||
                    key == "veyra.channelNameOverrides"),
                  let data = Data(base64Encoded: encoded), isSafeForLocalWrite(data),
                  let value = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            else { continue }
            let current = defaults.object(forKey: key)
            if let current, (current as AnyObject).isEqual(value) { continue }
            defaults.set(value, forKey: key)
            changed = true
            if key.hasPrefix("veyra.iptv.provider.preferences.") { iptvChanged = true }
        }
        if changed {
            if name == "livetv" {
                NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)
                NotificationCenter.default.post(name: .channelOverrideChanged, object: nil)
            } else {
                NotificationCenter.default.post(name: .veyraShelfConfigurationDidChange, object: nil)
                NotificationCenter.default.post(name: .veyraAddonConfigurationDidChange, object: nil)
                if iptvChanged {
                    NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)
                }
            }
        }
    }

    private func sameJSON(_ lhs: Data, _ rhs: Data) -> Bool {
        guard let left = try? JSONSerialization.jsonObject(with: lhs),
              let right = try? JSONSerialization.jsonObject(with: rhs)
        else { return lhs == rhs }
        return (left as AnyObject).isEqual(right)
    }

    private func decodeLogoOverrides(_ encoded: String?) -> [String: String]? {
        guard let encoded else { return [:] }
        guard let plist = Data(base64Encoded: encoded),
              let data = try? PropertyListSerialization.propertyList(
                from: plist, options: [], format: nil) as? Data,
              let urls = try? JSONDecoder().decode([String: String].self, from: data)
        else { return nil }
        return urls
    }

    private func mergeLogoOverrides(local: String?, old: String?,
                                    remote: String?) -> String? {
        guard local != nil || remote != nil else { return nil }
        guard let localURLs = decodeLogoOverrides(local),
              let remoteURLs = decodeLogoOverrides(remote),
              let oldURLs = decodeLogoOverrides(old) else { return remote }
        var result = remoteURLs
        if old == nil {
            for (channel, url) in localURLs where result[channel] == nil {
                result[channel] = url
            }
        } else {
            for channel in Set(localURLs.keys).union(oldURLs.keys) {
                let localValue = localURLs[channel]
                if localValue != oldURLs[channel],
                   remoteURLs[channel] == oldURLs[channel] {
                    result[channel] = localValue
                }
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(result),
              let plist = try? PropertyListSerialization.data(
                fromPropertyList: data, format: .binary, options: 0)
        else { return remote }
        return plist.base64EncodedString()
    }
}
