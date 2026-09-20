import Foundation

/// Eén rij in het "Gegevens en opslag"-scherm: een groep sleutels die
/// samen worden getoond, met hoeveel er lokaal versus in iCloud staan.
struct CloudSyncCategory: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    var localCount: Int
    var cloudCount: Int

    /// Ruwe grootte in bytes van wat dit apparaat voor deze categorie naar
    /// iCloud zou (kunnen) sturen — een schatting, zie `estimatedTotalBytes`.
    var estimatedBytes: Int
}

/// Spiegelt Veyra's lokale `UserDefaults`-instellingen naar/van iCloud's
/// sleutel-waardeopslag (`NSUbiquitousKeyValueStore`), zodat alles wat nu
/// per apparaat in `UserDefaults` staat — Afspelen, IPTV-weergave,
/// Ondertitels, Algemeen, Posterverrijking, Planken/Hero, brontypen-
/// volgorde, addons, favoriete sportteams — automatisch meegaat tussen elk
/// apparaat dat met hetzelfde iCloud-account is ingelogd. Puur
/// sleutel/waarde, geen CloudKit en geen eigen schema: dezelfde JSON die
/// elke bestaande `...Defaults`/`...Store` al in `UserDefaults` zet, gaat
/// ongewijzigd mee naar `NSUbiquitousKeyValueStore`.
///
/// Bewust NIET gesynchroniseerd:
/// - `AddonMigration`'s eenmalige migratievlag (`veyra.addons.migration.aioStreams.v1`)
///   — synchroniseren zou de migratie op een apparaat dat 'm nog niet
///   heeft gedraaid, onterecht overslaan.
/// - `JellyfinClient.persistentDeviceID()` — een per-installatie
///   apparaat-ID; delen zou iPhone en Apple TV voor Jellyfin laten
///   doorgaan voor hetzelfde apparaat.
/// - `ChannelLogoOverrideStore` — verwijst naar logobestanden op de lokale
///   schijf van dit apparaat, niet overdraagbaar via een sleutel/waarde-
///   opslag.
/// - Kijkvoortgang/watchlist: die lopen al via je Trakt-account (een eigen
///   API, dus al cross-device); Veyra houdt daarnaast geen eigen lokale
///   kopie bij om te synchroniseren. IPTV-provider-*inloggegevens* (Xtream/
///   M3U) staan niet hier, maar in de Keychain — zie
///   `IPTVConfigurationStore`, dat nu `kSecAttrSynchronizable` gebruikt
///   voor Apple's eigen versleutelde iCloud Keychain-sync, en daarom in de
///   UI apart wordt getoond (geen tel-/bytecijfer uit deze klasse).
@MainActor
final class CloudSettingsSync: ObservableObject {
    static let shared = CloudSettingsSync()

    private let store = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var started = false
    private var pushWorkItem: DispatchWorkItem?

    /// iCloud's eigen limiet voor `NSUbiquitousKeyValueStore` is 1 MB in
    /// totaal (per app, alle sleutels samen). Er is geen officiële API om
    /// het werkelijk gebruikte aantal bytes op te vragen — de opgegeven
    /// waarde hieronder is dus altijd een schatting op basis van wat dit
    /// apparaat zelf zou versturen, niet een gemeten iCloud-waarde.
    static let storeByteLimit = 1_000_000

    private static let enabledKey = "cloudSync.enabled"
    private static let lastSyncDateKey = "cloudSync.lastSyncDate"

    /// Aan/uit-schakelaar voor de hele functie. Staat 'm standaard aan —
    /// bestaande gebruikers van vóór deze functie krijgen sync zonder iets
    /// te hoeven doen, net als bij de referentie-app.
    @Published private(set) var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled {
                started = false
                start()
            }
        }
    }

    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var categories: [CloudSyncCategory] = []
    @Published private(set) var estimatedTotalBytes: Int = 0

    private init() {
        isEnabled = (defaults.object(forKey: Self.enabledKey) as? Bool) ?? true
        lastSyncDate = defaults.object(forKey: Self.lastSyncDateKey) as? Date
    }

    // MARK: - Vaste sleutels

    /// Simpele waarden (Bool/String/Int/Double) — meestal rechtstreeks via
    /// `@AppStorage` gelezen, dus een pull hier volstaat om de UI bij te
    /// werken; SwiftUI ziet de `UserDefaults`-wijziging vanzelf.
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
        // NB: "veyra.hero.style" wordt hier als kale sleutel meegenomen
        // (Hero-instellingen bestaan nog niet als eigen type in dit
        // project-exemplaar) — mocht die instelling later verschijnen, dan
        // gaat hij via dezelfde sleutelnaam vanzelf mee.
        simpleKeys + iptvDisplayKeys + subtitleKeys + generalKeys + ["veyra.hero.style"]
    }

    /// JSON-gecodeerde (`Data`) waarden — alleen via elke store's eigen
    /// load/save-methoden gelezen, dus een pull moet ook de bijbehorende
    /// bestaande wijzigingsmelding posten zodat een open scherm het
    /// zelf opnieuw inlaadt.
    // NB: Hero-instellingen (HeroSettingsDefaults) bestaan nog niet in dit
    // project-exemplaar en zijn hier bewust weggelaten — alleen de
    // plankvolgorde zelf wordt gesynchroniseerd.
    private static let shelfHeroDataKeys: [(key: String, notify: Notification.Name?)] = [
        ("veyra.shelves.configured", .veyraShelfConfigurationDidChange),
    ]

    private static let sourceOrderDataKeys: [(key: String, notify: Notification.Name?)] = [
        ("sourceOrder.categoryOrder", nil),
        ("sourceOrder.iptvProviderOrder", nil),
    ]

    private static let addonDataKeys: [(key: String, notify: Notification.Name?)] = [
        ("veyra.addons.installed", .veyraAddonConfigurationDidChange),
    ]

    private static var dataKeys: [(key: String, notify: Notification.Name?)] {
        shelfHeroDataKeys + sourceOrderDataKeys + addonDataKeys
    }

    private static let metadataPrefix = "metadata.rating."
    private static let iptvVisibilityPrefix = "veyra.iptv.provider.preferences."

    private static let dynamicPrefixes: [String] = [metadataPrefix, iptvVisibilityPrefix]

    // MARK: - Start

    /// Eenmalig aan te roepen bij app-start (zie `VeyraApp`/`Veyra_iOSApp`).
    func start() {
        refreshStatus()
        guard isEnabled, !started else { return }
        started = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleExternalChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store)

        NotificationCenter.default.addObserver(
            self, selector: #selector(scheduleLocalPush),
            name: UserDefaults.didChangeNotification, object: defaults)

        store.synchronize()
        mergeOnFirstRun()
        refreshStatus()
    }

    /// Zet de functie aan of uit. Uitzetten stopt alleen het automatisch
    /// mee-spiegelen bij toekomstige wijzigingen — wat al in iCloud staat,
    /// wordt niet gewist (zie ook `forgetCloudCopy()` hieronder).
    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        if !enabled {
            NotificationCenter.default.removeObserver(
                self, name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store)
            NotificationCenter.default.removeObserver(
                self, name: UserDefaults.didChangeNotification, object: defaults)
            started = false
        }
        isEnabled = enabled
    }

    // MARK: - Eerste samenvoeging

    /// Bij het allereerste opstarten op een apparaat: waar alleen iCloud
    /// een waarde heeft, die overnemen; waar alleen dit apparaat er een
    /// heeft, die omhoog duwen. Staat de sleutel op BEIDE plekken (bv. elk
    /// apparaat had z'n eigen instelling vóór deze functie bestond), dan
    /// wint voorlopig de lokale waarde — `NSUbiquitousKeyValueStore` geeft
    /// geen tijdstempels, dus "nieuwste wint" is hier niet te bepalen
    /// zonder een eigen schema erbovenop.
    private func mergeOnFirstRun() {
        for key in Self.simpleKeysAll {
            mergeSimple(key)
        }
        for (key, _) in Self.dataKeys {
            mergeData(key)
        }
        for prefix in Self.dynamicPrefixes {
            for key in allKeys(withPrefix: prefix) {
                mergeData(key)
            }
        }
        markSynced()
    }

    private func mergeSimple(_ key: String) {
        let local = defaults.object(forKey: key)
        let cloud = store.object(forKey: key)

        if local == nil, let cloud {
            setLocal(cloud, forKey: key)
        } else if cloud == nil, let local {
            store.set(local, forKey: key)
        }
    }

    private func mergeData(_ key: String) {
        let local = defaults.data(forKey: key)
        let cloud = store.data(forKey: key)

        if local == nil, let cloud {
            defaults.set(cloud, forKey: key)
        } else if cloud == nil, let local {
            store.set(local, forKey: key)
        }
    }

    // MARK: - Lokaal -> iCloud

    @objc private func scheduleLocalPush() {
        // `UserDefaults.didChangeNotification` vuurt bij ELKE wijziging,
        // zonder te zeggen welke sleutel — en vuurt vaak meerdere keren
        // vlak na elkaar. Een korte debounce voorkomt dat elke toggle een
        // volledige vergelijking van alle sleutels triggert.
        pushWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.pushAll() }
        pushWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    private func pushAll() {
        for key in Self.simpleKeysAll {
            guard let value = defaults.object(forKey: key) else { continue }
            if !isEqual(value, store.object(forKey: key)) {
                store.set(value, forKey: key)
            }
        }

        for (key, _) in Self.dataKeys {
            guard let value = defaults.data(forKey: key) else { continue }
            if value != store.data(forKey: key) {
                store.set(value, forKey: key)
            }
        }

        for prefix in Self.dynamicPrefixes {
            for key in allKeys(withPrefix: prefix) {
                guard let value = defaults.data(forKey: key) else { continue }
                if value != store.data(forKey: key) {
                    store.set(value, forKey: key)
                }
            }
        }

        store.synchronize()
        markSynced()
    }

    // MARK: - iCloud -> lokaal

    @objc private func handleExternalChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let changedKeys =
                userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        else {
            return
        }

        var notificationsToPost: Set<Notification.Name> = []

        for key in changedKeys {
            if Self.simpleKeysAll.contains(key) {
                if let value = store.object(forKey: key) {
                    setLocal(value, forKey: key)
                }
                continue
            }

            if let entry = Self.dataKeys.first(where: { $0.key == key }) {
                if let value = store.data(forKey: key) {
                    defaults.set(value, forKey: key)
                }
                if let notify = entry.notify { notificationsToPost.insert(notify) }
                continue
            }

            if Self.dynamicPrefixes.contains(where: { key.hasPrefix($0) }) {
                if let value = store.data(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
        }

        for name in notificationsToPost {
            NotificationCenter.default.post(name: name, object: nil)
        }

        markSynced()
        refreshStatus()
    }

    // MARK: - Handmatig (instellingenscherm)

    /// "Stuur naar iCloud" — forceert een volledige push, ook van sleutels
    /// die al gelijk lijken (nuttig als de gebruiker vermoedt dat een ander
    /// apparaat is blijven hangen).
    func forcePushAll() {
        guard isEnabled else { return }
        for key in Self.simpleKeysAll {
            if let value = defaults.object(forKey: key) {
                store.set(value, forKey: key)
            }
        }
        for (key, _) in Self.dataKeys {
            if let value = defaults.data(forKey: key) {
                store.set(value, forKey: key)
            }
        }
        for prefix in Self.dynamicPrefixes {
            for key in allKeys(withPrefix: prefix) {
                if let value = defaults.data(forKey: key) {
                    store.set(value, forKey: key)
                }
            }
        }
        store.synchronize()
        markSynced()
        refreshStatus()
    }

    /// "Haal op uit iCloud" — overschrijft lokale waarden met wat er in
    /// iCloud staat, voor elke sleutel die daar een waarde heeft.
    func forcePullAll() {
        guard isEnabled else { return }
        store.synchronize()

        var shelfHeroChanged = false
        var addonsChanged = false

        for key in Self.simpleKeysAll {
            if let value = store.object(forKey: key) {
                setLocal(value, forKey: key)
            }
        }
        for (key, notify) in Self.dataKeys {
            if let value = store.data(forKey: key) {
                defaults.set(value, forKey: key)
                if notify == .veyraShelfConfigurationDidChange { shelfHeroChanged = true }
                if notify == .veyraAddonConfigurationDidChange { addonsChanged = true }
            }
        }
        for prefix in Self.dynamicPrefixes {
            for key in allKeys(withPrefix: prefix) {
                if let value = store.data(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
        }

        if shelfHeroChanged {
            NotificationCenter.default.post(name: .veyraShelfConfigurationDidChange, object: nil)
        }
        if addonsChanged {
            NotificationCenter.default.post(name: .veyraAddonConfigurationDidChange, object: nil)
        }

        markSynced()
        refreshStatus()
    }

    /// "Reset iCloud-kopie" — wist alleen wat in iCloud staat; laat dit
    /// apparaat's eigen instellingen ongemoeid. Handig als een oude,
    /// verwarde synchronisatie helemaal opnieuw moet beginnen.
    func forgetCloudCopy() {
        for key in Self.simpleKeysAll {
            store.removeObject(forKey: key)
        }
        for (key, _) in Self.dataKeys {
            store.removeObject(forKey: key)
        }
        for prefix in Self.dynamicPrefixes {
            for key in allKeys(withPrefix: prefix) {
                store.removeObject(forKey: key)
            }
        }
        store.synchronize()
        refreshStatus()
    }

    private func markSynced() {
        let now = Date()
        lastSyncDate = now
        defaults.set(now, forKey: Self.lastSyncDateKey)
    }

    // MARK: - Status (voor het instellingenscherm)

    /// Herberekent de per-categorie tellingen en de geschatte totale
    /// grootte. Roep dit aan wanneer het scherm verschijnt en na elke
    /// handmatige actie — dit is bewust geen doorlopende observatie, om
    /// niet bij elke los toetsaanslag alle sleutels opnieuw te tellen.
    func refreshStatus() {
        store.synchronize()

        var newCategories: [CloudSyncCategory] = []
        var totalBytes = 0

        func count(_ keys: [String]) -> (local: Int, cloud: Int, bytes: Int) {
            var local = 0
            var cloud = 0
            var bytes = 0
            for key in keys {
                if defaults.object(forKey: key) != nil { local += 1 }
                if store.object(forKey: key) != nil { cloud += 1 }
                bytes += approximateByteSize(ofKey: key, isData: false)
            }
            return (local, cloud, bytes)
        }

        func countData(_ entries: [(key: String, notify: Notification.Name?)]) -> (local: Int, cloud: Int, bytes: Int) {
            var local = 0
            var cloud = 0
            var bytes = 0
            for (key, _) in entries {
                if defaults.data(forKey: key) != nil { local += 1 }
                if store.data(forKey: key) != nil { cloud += 1 }
                bytes += approximateByteSize(ofKey: key, isData: true)
            }
            return (local, cloud, bytes)
        }

        func countPrefix(_ prefix: String) -> (local: Int, cloud: Int, bytes: Int) {
            let keys = allKeys(withPrefix: prefix)
            var local = 0
            var cloud = 0
            var bytes = 0
            for key in keys {
                if defaults.data(forKey: key) != nil { local += 1 }
                if store.data(forKey: key) != nil { cloud += 1 }
                bytes += approximateByteSize(ofKey: key, isData: true)
            }
            return (local, cloud, bytes)
        }

        let general = count(Self.generalKeys + Self.subtitleKeys + Self.iptvDisplayKeys)
        newCategories.append(CloudSyncCategory(
            id: "settings", title: "Instellingen",
            subtitle: "Afspelen, weergave, ondertitels, IPTV-weergave",
            symbol: "gearshape",
            localCount: general.local + count(Self.simpleKeys).local,
            cloudCount: general.cloud + count(Self.simpleKeys).cloud,
            estimatedBytes: general.bytes + count(Self.simpleKeys).bytes))

        let shelfHero = countData(Self.shelfHeroDataKeys)
        newCategories.append(CloudSyncCategory(
            id: "shelves", title: "Planken & Hero",
            subtitle: "Volgorde en indeling van je hoofdmenu",
            symbol: "rectangle.grid.1x2",
            localCount: shelfHero.local, cloudCount: shelfHero.cloud,
            estimatedBytes: shelfHero.bytes))

        let sourceOrder = countData(Self.sourceOrderDataKeys)
        newCategories.append(CloudSyncCategory(
            id: "sourceOrder", title: "Brontypenvolgorde",
            subtitle: "Volgorde van categorieën en IPTV-providers",
            symbol: "arrow.up.arrow.down",
            localCount: sourceOrder.local, cloudCount: sourceOrder.cloud,
            estimatedBytes: sourceOrder.bytes))

        let addons = countData(Self.addonDataKeys)
        newCategories.append(CloudSyncCategory(
            id: "addons", title: "Addons",
            subtitle: "Geïnstalleerde addons en hun instellingen",
            symbol: "puzzlepiece.extension",
            localCount: addons.local, cloudCount: addons.cloud,
            estimatedBytes: addons.bytes))

        let metadata = countPrefix(Self.metadataPrefix)
        newCategories.append(CloudSyncCategory(
            id: "metadata", title: "Metadata-voorkeuren",
            subtitle: "Welke beoordelingsbron je per titel koos",
            symbol: "star.leadinghalf.filled",
            localCount: metadata.local, cloudCount: metadata.cloud,
            estimatedBytes: metadata.bytes))

        let iptvVisibility = countPrefix(Self.iptvVisibilityPrefix)
        newCategories.append(CloudSyncCategory(
            id: "iptvVisibility", title: "IPTV-zichtbaarheid",
            subtitle: "Zender- en categorievoorkeuren per provider",
            symbol: "eye",
            localCount: iptvVisibility.local, cloudCount: iptvVisibility.cloud,
            estimatedBytes: iptvVisibility.bytes))

        for category in newCategories {
            totalBytes += category.estimatedBytes
        }

        categories = newCategories
        estimatedTotalBytes = totalBytes
    }

    /// Grove schatting van wat één sleutel aan opslag kost: de UTF-8-
    /// grootte van de lokale waarde (of, bij ontbreken, de iCloud-waarde)
    /// plus de sleutelnaam zelf. `NSUbiquitousKeyValueStore` rekent ook de
    /// sleutelnamen mee in de 1 MB-limiet, dus die tellen hier mee.
    private func approximateByteSize(ofKey key: String, isData: Bool) -> Int {
        let keyBytes = key.utf8.count

        if isData {
            let bytes = defaults.data(forKey: key)?.count ?? store.data(forKey: key)?.count ?? 0
            return keyBytes + bytes
        }

        if let value = defaults.object(forKey: key) ?? store.object(forKey: key) {
            switch value {
            case let s as String: return keyBytes + s.utf8.count
            case let d as Data: return keyBytes + d.count
            case let array as [String]: return keyBytes + array.reduce(0) { $0 + $1.utf8.count }
            default: return keyBytes + 8
            }
        }

        return 0
    }

    // MARK: - Hulpfuncties

    private func setLocal(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    private func isEqual(_ lhs: Any, _ rhs: Any?) -> Bool {
        guard let rhs else { return false }
        switch (lhs, rhs) {
        case (let a as String, let b as String): return a == b
        case (let a as Bool, let b as Bool): return a == b
        case (let a as Int, let b as Int): return a == b
        case (let a as Int64, let b as Int64): return a == b
        case (let a as Double, let b as Double): return a == b
        case (let a as Data, let b as Data): return a == b
        case (let a as [String], let b as [String]): return a == b
        default: return false
        }
    }

    private func allKeys(withPrefix prefix: String) -> Set<String> {
        var keys = Set<String>()

        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            keys.insert(key)
        }
        for key in store.dictionaryRepresentation.keys where key.hasPrefix(prefix) {
            keys.insert(key)
        }

        return keys
    }
}
