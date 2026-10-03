// VeyraBentoHomeIOS.swift — iOS 17+ / macOS 14+
// De bento-home voor telefoon en tablet: hero + zes tegels in een raster + optioneel de sectie Sport.
//   iPhone (compact)   2 kolommen: Verder kijken en Live nu over de volle breedte, Vandaag naast Tijd/Bronnen,
//                      Nieuw toegevoegd onderaan
//   iPad (regular)     6 kolommen: Verder kijken over de volle breedte, daaronder Live nu | Vandaag, dan Tijd | Bronnen, Nieuw onderaan
//
// Bediening: tik = hoofdactie van de tegel (afspelen / zender openen / herinnering), lang indrukken = keuzemenu,
// omlaag trekken = alles opnieuw laden. Zelfde API als de tvOS-versie (VeyraBentoHome.swift).
// Vereist: VeyraBentoLayout/Model/Tiles.swift, VeyraBentoFocus.swift (VeyraPressStyle), VeyraBentoHeroIOS.swift,
//          VeyraBentoStyle.swift, VeyraBentoTrakt.swift, VeyraBentoEPGModel.swift, en voor Sport: VeyraSport*.swift.

#if !os(tvOS)
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct VeyraBentoHomeView: View {
    @State private var model: VeyraBentoViewModel
    private let sportModel: VeyraSportViewModel?
    @State private var heroSpotlight = VeyraHeroSpotlightController()
    @State private var trendingItems: [HeroSpotlightItem] = []
    @State private var voorJouItems: [HeroSpotlightItem] = []
    @State private var top10Items: [HeroSpotlightItem] = []
    @Environment(\.playMediaItem) private var playMediaItem

    var onPlay: (ContinueItem) -> Void
    var onToggleReminder: (UpcomingItem, Bool) -> Void
    var onOpenLiveTV: (String?) -> Void
    var onPlayChannel: (String) -> Void
    var onOpenIPTVFilm: (IPTVHomeFilm) -> Void
    var onOpenIPTVSeries: (IPTVHomeSeries) -> Void
    var onOpenTMDBTitle: (BentoTMDBTitle) -> Void
    var onOpenCatalog: (BentoCatalog) -> Void
    var onOpenNew: () -> Void
    var onOpenSources: () -> Void
    var onPlaySport: (SportEvent, SportPlayback) -> Void
    var onToggleSportReminder: (SportEvent, Bool) -> Void
    var onOpenCompetition: (SportCompetition) -> Void

    // Zoek-/instellingenknoppen: als gewoon eerste element boven in de scrollende inhoud (geen vaste/
    // zwevende balk) -- ze schuiven dus gewoon mee omhoog en verdwijnen bij het scrollen, i.p.v. altijd
    // zichtbaar te blijven staan.
    var floatingButtons = false
    var showsSettings = true
    var onSearch: () -> Void = {}
    var onSettings: () -> Void = {}

    @AppStorage(GeneralSettingsDefaults.showContinueWatchingKey) private var showContinueWatching = true
    @AppStorage(TMDBCatalogLanguageFilter.key) private var catalogLanguages = "nl-en"
    @AppStorage(GeneralSettingsDefaults.showUpcomingKey) private var showUpcoming = true
    @AppStorage(GeneralSettingsDefaults.liveFavoritesOnlyKey) private var liveFavoritesOnly = false
    // Op iPad met de zwevende menubalk boven (i.p.v. zijbalk, zie `ContentView`/
    // `IPadNavigationStyle`) zweeft die balk over de volle breedte vlak onder de
    // statuszone -- de hero negeert de safe area bewust (zie `homeHeroTopInset`)
    // om zelf tot onder de statuszone door te lopen, waardoor de diensten-rij
    // anders ONDER die zwevende balk terechtkomt i.p.v. erna. Zelfde sleutel als
    // `ContentView` leest.
    @AppStorage(GeneralSettingsDefaults.ipadNavigationStyleKey) private var ipadNavigationStyleRaw = IPadNavigationStyle.sidebar.rawValue
    @State private var layout = VeyraHomeLayoutStore.load()
    @State private var nowSettings = VeyraNowSettingsStore.load()
    @State private var askPreset = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var regular: Bool { sizeClass == .regular }
    #else
    private var regular: Bool { true }
    #endif

    init(model: VeyraBentoViewModel,
         sportModel: VeyraSportViewModel? = nil,
         onPlay: @escaping (ContinueItem) -> Void,
         onToggleReminder: @escaping (UpcomingItem, Bool) -> Void = { _, _ in },
         onOpenLiveTV: @escaping (String?) -> Void = { _ in },
         onPlayChannel: @escaping (String) -> Void = { _ in },
         onOpenIPTVFilm: @escaping (IPTVHomeFilm) -> Void = { _ in },
         onOpenIPTVSeries: @escaping (IPTVHomeSeries) -> Void = { _ in },
         onOpenTMDBTitle: @escaping (BentoTMDBTitle) -> Void = { _ in },
         onOpenCatalog: @escaping (BentoCatalog) -> Void = { _ in },
         onOpenNew: @escaping () -> Void = {},
         onOpenSources: @escaping () -> Void = {},
         onPlaySport: @escaping (SportEvent, SportPlayback) -> Void = { _, _ in },
         onToggleSportReminder: @escaping (SportEvent, Bool) -> Void = { _, _ in },
         onOpenCompetition: @escaping (SportCompetition) -> Void = { _ in },
         floatingButtons: Bool = false,
         showsSettings: Bool = true,
         onSearch: @escaping () -> Void = {},
         onSettings: @escaping () -> Void = {}) {
        _model = State(initialValue: model)
        self.sportModel = sportModel
        self.onPlay = onPlay
        self.onToggleReminder = onToggleReminder
        self.onOpenLiveTV = onOpenLiveTV
        self.onPlayChannel = onPlayChannel
        self.onOpenIPTVFilm = onOpenIPTVFilm
        self.onOpenIPTVSeries = onOpenIPTVSeries
        self.onOpenTMDBTitle = onOpenTMDBTitle
        self.onOpenCatalog = onOpenCatalog
        self.onOpenNew = onOpenNew
        self.onOpenSources = onOpenSources
        self.onPlaySport = onPlaySport
        self.onToggleSportReminder = onToggleSportReminder
        self.onOpenCompetition = onOpenCompetition
        self.floatingButtons = floatingButtons
        self.showsSettings = showsSettings
        self.onSearch = onSearch
        self.onSettings = onSettings
    }

    // MARK: Body

    var body: some View {
        VeyraDynamicBackgroundScope {
            GeometryReader { rootGeo in
                // Beschikbare breedte binnen de compacte zijmarge van 12pt,
                // zodat de horizontaal scrollende rijen hun vaste kaartbreedtes hierop kunnen clampen en NOOIT
                // breder worden dan het scherm — op elk toestel, ook grotere iPhones die per ongeluk `regular` zijn.
                let contentWidth = max(rootGeo.size.width - 24, 0)

                VeyraScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if showsHero || showsStreamingRibbon || floatingButtons {
                            homeHeader(availableHeight: rootGeo.size.height)
                        }

                        VStack(alignment: .leading, spacing: 32) {
                            // "Context Ribbon": rouleert door Nu/volgende aflevering/live nu/sport --
                            // onderaan de hero, zodat Home meteen anders aanvoelt (zie ook de kleinere
                            // Pulse-badge in de hero zelf hierboven, `continueRibbonInfo`).
                            TimelineView(.periodic(from: .now, by: 5)) { context in
                                VeyraContextRibbon(items: contextRibbonItems(now: context.date), now: context.date)
                            }

                            if let message = model.home.notice {
                                VeyraStatusMessage(text: message) { Task { await model.load(force: true) } }
                            }

                            // "Verder kijken" en "Binnenkort" helemaal bovenaan, net als op tvOS.
                            TimelineView(.periodic(from: .now, by: 30)) { context in
                                bentoTop(now: context.date, contentWidth: contentWidth)
                            }

                            VeyraYourCollectionsSection()

                            // "Live nu" hier vlak onder "Jouw collecties" (op uitdrukkelijk verzoek
                            // verplaatst, stond voorheen verderop samen met "Voor jou").
                            TimelineView(.periodic(from: .now, by: 30)) { context in
                                bentoMiddle(now: context.date, contentWidth: contentWidth, tiles: [.live])
                            }

                            // "Nieuw van hier" (Regional Releases fase 4/10, spec §4/§30): op tvOS
                            // staat dit als eigen prominente rij met focus/kalender-modus
                            // (`VeyraRegionalReleasesRow`, tvOS-only i.v.m. focus-afhandeling) --
                            // op iOS/iPadOS was deze sectie tot nu toe nergens aangesloten (de hele
                            // tvOS Home-file is `#if os(tvOS)`), waardoor "Nieuw van hier" hier
                            // volledig ontbrak. Dit is de iOS-tegenhanger: een gewone horizontale
                            // plank (`VeyraBentoShelf`), geen eigen kalenderweergave/live-knop --
                            // tikken opent dezelfde bestaande TMDB-titelroute als op tvOS.
                            TimelineView(.periodic(from: .now, by: 30)) { context in
                                bentoRegional(now: context.date)
                            }
                            // Iets extra ruimte boven "Nieuw van hier": stond anders te krap
                            // tegen "Live nu" erboven aan.
                            .padding(.top, 12)

                            // "Discovery Flow": Trending, los van het bento-raster -- Stap 9 van het
                            // Home Visual System-spec, direct na "Verder kijken" (spec §97), net als op tvOS.
                            VeyraDiscoveryFlow(title: "Trending", items: trendingItems)

                            // "Dynamic Mosaic": Voor Jou -- Stap 10, direct na Trending (spec §97).
                            VeyraMosaicSection(title: "Voor jou", items: voorJouItems)

                            // "Binnenkort" teruggezet in "Verder kijken"-rij (zie bentoTop) -- geen
                            // losse Calendar Horizon-sectie meer.

                            // "Sports Stage": uitgelichte live wedstrijd, los van de rest van de
                            // Sport-sectie -- Stap 14, direct na Nu op tv, vóór Live Sport (spec §97).
                            TimelineView(.periodic(from: .now, by: 30)) { context in
                                bentoSportsStage(now: context.date)
                            }

                            // Sport onder "Streamingdiensten", net als op tvOS.
                            if layout.showSport, let sportModel, !sportModel.events.isEmpty {
                                SportSection(
                                    model: sportModel,
                                    regular: regular,
                                    onPlay: onPlaySport,
                                    onToggleReminder: onToggleSportReminder,
                                    onOpenCompetition: onOpenCompetition)
                            } else if layout.showSport, let sportModel, sportModel.phase != .idle, sportModel.phase != .loading {
                                Button { onOpenCompetition(SportCompetition(name: "Sport", liveCount: 0, eventCount: 0, nextStart: nil)) } label: {
                                    VeyraStatusMessage(text: "Sport: geen wedstrijden gevonden. Tik om het Sport-menu te openen.")
                                }
                                .buttonStyle(.plain)
                            }

                            // "IPTV films"/"IPTV series" pas na Sport, net als op tvOS.
                            TimelineView(.periodic(from: .now, by: 30)) { context in
                                bentoIPTV(now: context.date)
                            }

                            if layout.showShelves { VeyraBentoUserShelves(compact: true, onOpen: onOpenTMDBTitle) }
                        }
                        .padding(.horizontal, 12)
                        // Een kleine afstand tussen de hero en de eerste rij.
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                    .background(VeyraScrollPositionReader())
                }
                .scrollIndicators(.hidden)

                .refreshable {
                    await model.load(force: true)
                    await sportModel?.load()
                }
                .task { await model.load() }
                // Trending/Voor jou/Top 10 na elkaar laden, niet gelijktijdig --
                // zelfde reden als op tvOS: te veel gelijktijdige TMDB-clearlogo-
                // verzoeken bovenop de IPTV-opstart-ververs duwde het geheugen te
                // hoog (app-crash bij opstart).
                .task {
                    trendingItems = await HeroSpotlightLoader.load(settings: .default)
                    voorJouItems = await HeroSpotlightLoader.load(settings: HeroSpotlightSettings(
                        style: .card,
                        primarySource: .trakt(list: .watchlist, kind: .movie),
                        secondarySource: .trakt(list: .watchlist, kind: .series)
                    ))
                    top10Items = await HeroSpotlightLoader.load(settings: HeroSpotlightSettings(
                        style: .card,
                        primarySource: .tmdb(list: .popular, kind: .movie),
                        secondarySource: .tmdb(list: .popular, kind: .series)
                    ))
                }
                .onChange(of: catalogLanguages) { _, _ in Task { await model.load(force: true) } }
                .onReceive(NotificationCenter.default.publisher(for: .veyraHomeLayoutDidChange)) { _ in reloadLayout() }
                .onReceive(NotificationCenter.default.publisher(for: .veyraNowSettingsDidChange)) { _ in nowSettings = VeyraNowSettingsStore.load() }
                .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in reloadLayout() }
                // Anders blijven "IPTV films"/"IPTV series" de oude, al-in-memory
                // lijst tonen totdat je handmatig ververst (pull-to-refresh) of de
                // app herstart, ook als je net iets verborgen hebt bij "VOD beheren".
                .onReceive(NotificationCenter.default.publisher(for: .iptvConfigurationDidChange)) { _ in
                    Task { await model.load(force: true) }
                }
                // Aflevering/film afgekeken (Trakt-stop): "Verder kijken" meteen opnieuw ophalen.
                .onReceive(NotificationCenter.default.publisher(for: .veyraTraktHistoryDidChange)) { _ in
                    Task { await model.load(force: true) }
                }
                .onReceive(NotificationCenter.default.publisher(for: .veyraTraktSnapshotDidChange)) { _ in
                    Task { await model.home.refreshContinueOrder() }
                }
                .onAppear { askPreset = !VeyraHomeLayoutStore.hasChosen }
                .sheet(isPresented: $askPreset, onDismiss: { VeyraHomeLayoutStore.markChosen() }) {
                    VeyraHomePresetPickerView { askPreset = false }
                }
                .task { if let sportModel, sportModel.phase == .idle { await sportModel.load() } }
                .task { heroSpotlight.reloadIfNeeded() }
                .onReceive(NotificationCenter.default.publisher(for: .heroSpotlightSettingsChanged)) { _ in
                    heroSpotlight.settingsChanged()
                }
                .task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(120))
                        if Task.isCancelled { break }
                        await model.refreshLive()
                        if let sportModel, sportModel.events.isEmpty { await sportModel.reload() }
                    }
                }
            }
            .background(VeyraBackground())
            #if os(iOS)
            // Het beeld vult ook de statuszone; de scrollende bediening heeft eigen veilige bovenruimte.
            .ignoresSafeArea(edges: showsHero && heroSpotlight.settings.style == .fullscreen ? .top : [])
            #endif

        }
    }

    private var isPad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    /// Hoogte van de zwevende menubalk boven op iPad (Home/Films/Series/…) wanneer die balk-stijl
    /// actief is i.p.v. de zijbalk -- geschatte waarde (systeem geeft deze niet rechtstreeks door
    /// zodra de hero zijn eigen `.ignoresSafeArea()` gebruikt).
    private var floatingTopTabBarHeight: CGFloat {
        guard isPad, (IPadNavigationStyle(rawValue: ipadNavigationStyleRaw) ?? .sidebar) == .topBar else { return 0 }
        return 64
    }

    private var homeHeroTopInset: CGFloat {
        #if os(iOS)
        showsHero && heroSpotlight.settings.style == .fullscreen
            ? VeyraSafeArea.top + floatingTopTabBarHeight
            : 0
        #else
        0
        #endif
    }

    private var streamingRibbonHeight: CGFloat {
        showsStreamingRibbon ? (regular ? 72 : 64) : 0
    }

    @ViewBuilder
    private func homeHeader(availableHeight: CGFloat) -> some View {
        if showsHero {
            VeyraHomeHeroHeader(fullscreen: heroSpotlight.settings.style == .fullscreen,
                                topInset: homeHeroTopInset) {
                hero(availableHeight: availableHeight)
            } services: {
                streamingRibbon
            } controls: {
                homeControls
            }
        } else {
            VStack(spacing: 0) {
                streamingRibbon
                homeControls
            }
        }
    }

    @ViewBuilder
    private var homeControls: some View {
        if floatingButtons {
            HStack {
                FloatingIconButton(symbol: "magnifyingglass", accessibilityLabel: "Zoeken", action: onSearch)
                Spacer()
                if showsSettings {
                    FloatingIconButton(symbol: "gearshape.fill", accessibilityLabel: "Instellingen", action: onSettings)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private func scrollingHeroHeight(availableHeight: CGFloat) -> CGFloat {
        heroHeight(availableHeight: availableHeight)
            + (heroSpotlight.settings.style == .fullscreen ? homeHeroTopInset + streamingRibbonHeight : 0)
    }

    /// Of er momenteel iets is om als hero te tonen -- gebruikt door `body` om `hero` enkel als
    /// VStack-kind op te nemen wanneer dat zo is. Anders telt de vaste `spacing` van die VStack
    /// nog steeds mee als lege ruimte, waardoor "Verder kijken"/"Binnenkort"/"Filmcollecties"
    /// ongewenst mee opschuiven ook al toont `hero` zelf niets.
    private var showsHero: Bool {
        !heroSpotlight.items.isEmpty || model.home.phase == .loading || model.home.phase == .idle
    }

    @ViewBuilder
    private func hero(availableHeight: CGFloat) -> some View {
        // Nieuwe trending-carrousel (Instellingen → Home → Hero) vervangt de
        // vroegere "verder kijken"-hero; die rij blijft wel bestaan als
        // gewone "Verder kijken"-sectie in `bentoTop`.
        if !heroSpotlight.items.isEmpty {
            // Negatieve horizontale padding compenseert de vaste `.padding(.horizontal, 16)`
            // van de omliggende VStack, zodat "Schermvullend" ook echt rand-tot-rand gaat.
            // `hero` staat nu als eigen VStack-kind vóór de zijmarge-gepadde inhoud
            // hieronder, dus geen negatieve padding meer nodig om "Schermvullend" rand-tot-rand
            // te krijgen -- enkel "Kaart" krijgt hier nog eigen zijmarge.
            VeyraHeroSpotlightView(items: heroSpotlight.items,
                                   style: heroSpotlight.settings.style,
                                   height: scrollingHeroHeight(availableHeight: availableHeight),
                                   onIndexChange: { heroSpotlight.currentIndex = $0 },
                                   contextInfo: continueRibbonInfo)
                .padding(.horizontal, heroSpotlight.settings.style == .card ? 16 : 0)
        } else if model.home.phase == .loading || model.home.phase == .idle {
            ProgressView().tint(.white).frame(maxWidth: .infinity).frame(height: scrollingHeroHeight(availableHeight: availableHeight))
        }
    }

    /// "Context Ribbon": als het gespotlighte item ook in Verder kijken staat,
    /// toont de hero meteen waar de gebruiker gebleven was (aflevering/
    /// resterende tijd) i.p.v. enkel de algemene titelinfo. Simpele, veilige
    /// eerste versie: alleen Verder kijken, geen "vanavond live"/sport nog
    /// (die databronnen zijn hier niet beschikbaar).
    private func continueRibbonInfo(_ item: HeroSpotlightItem) -> VeyraPulseInfo? {
        guard let tmdbID = item.mediaItem.tmdbID,
              let match = model.home.continueItems.first(where: { $0.tmdbID == tmdbID })
        else { return nil }
        return VeyraPulseInfo(kind: item.isMovie ? .movie : .series, text: "Verder kijken · \(match.baseMetaText)")
    }

    // MARK: Veyra Now (Context Ribbon)
    // Elke kandidaat krijgt een relevantiescore mee -- de ribbon zelf sorteert
    // erop, dus wat nú het meest telt (wedstrijd bijna afgelopen > zender die
    // net begint > gewoon verder kijken > iets dat pas later komt) staat vooraan.

    /// Haalt de ontbrekende stukjes (imdbID, seizoen/aflevering) op en stuurt daarna
    /// rechtstreeks naar bronkeuze -- zie `contextRibbonItems`, "Verder kijken".
    private func playContinueItemSource(_ item: ContinueItem) async {
        guard let tmdbID = item.tmdbID, tmdbID > 0 else { return }
        if item.kind == .movie {
            guard let service = TMDBService(), let resolved = try? await service.mediaItem(forMovieID: tmdbID) else { return }
            playMediaItem(resolved)
        } else {
            guard let service = SeriesService() else { return }
            let imdbID = try? await service.externalIDs(forSeriesID: tmdbID).imdbID
            let (season, episode) = Self.parseEpisodeCode(item.episodeCode)
            playMediaItem(MediaItem(
                title: item.title, type: .series, imdbID: imdbID, tmdbID: tmdbID,
                seasonNumber: season, episodeNumber: episode, backdropURL: item.backdropURL))
        }
    }

    /// "S2E4" -> (2, 4).
    private static func parseEpisodeCode(_ code: String?) -> (season: Int?, episode: Int?) {
        guard let code, code.hasPrefix("S") else { return (nil, nil) }
        let parts = code.dropFirst().split(separator: "E", maxSplits: 1)
        guard parts.count == 2, let season = Int(parts[0]), let episode = Int(parts[1]) else { return (nil, nil) }
        return (season, episode)
    }

    private func contextRibbonItems(now: Date) -> [VeyraRibbonItem] {
        var items: [VeyraRibbonItem] = []

        // Een weggetikt item ("Niet interessant"/"Vandaag niet") laat geen gat vallen --
        // dit blok stelt gewoon het eerstvolgende, nog niet weggetikte item voor uit
        // dezelfde (Trakt-gevoede) lijst i.p.v. dat het brontype helemaal verdwijnt.
        if showContinueWatching,
           let item = model.home.continueItems.first(where: { !nowSettings.isHidden("ribbon-continue-\($0.id)", now: now) }) {
            // Slimme prioriteit: een serie met nog maar 1-2 afleveringen te gaan is relevanter
            // dan eentje waar de kijker net aan begonnen is.
            let continuePriority: Double = {
                guard nowSettings.smartPriority, let left = item.episodesLeft else { return 50 }
                if left <= 1 { return 88 }
                if left <= 3 { return 72 }
                return 50
            }()
            let continueID = "ribbon-continue-\(item.id)"
            items.append(VeyraRibbonItem(
                id: continueID, icon: "play.fill", label: "VERDER KIJKEN",
                text: item.title, detail: item.subtitle ?? item.baseMetaText, contentKind: .continueWatching,
                priority: continuePriority, logoURL: item.logoURL, backdropURL: item.backdropURL,
                tmdbID: item.tmdbID, isMovie: item.kind == .movie,
                reason: item.episodesLeft == 1 ? .almostFinished : .continueWatching,
                reasonText: item.episodesLeft == 1 ? "Nog 1 aflevering" : nil,
                onDismiss: { VeyraNowSettingsStore.dismiss(continueID) },
                onSnooze: { VeyraNowSettingsStore.snoozeForToday(continueID) },
                // Veyra Now "Verder kijken" gaat rechtstreeks naar bronkeuze i.p.v. via het
                // detailscherm -- de kijker weet al wat dit is, die stond er net nog middenin.
                action: { Task { await playContinueItemSource(item) } }))
        }

        if showUpcoming,
           let item = model.today(at: now, limit: Int.max)?.items.first(where: { !nowSettings.isHidden("ribbon-upcoming-\($0.id)", now: now) }) {
            let minutesUntilAiring = item.airDate.timeIntervalSince(now) / 60
            let airingSoon = !item.isDateOnly && minutesUntilAiring > 0 && minutesUntilAiring <= 180
            let startText = item.isDateOnly
                ? item.airDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(VeyraHomeFormat.locale))
                : item.airDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute().locale(VeyraHomeFormat.locale))
            let detail = [item.subtitle, startText].compactMap { $0 }.joined(separator: " · ")
            let upcomingID = "ribbon-upcoming-\(item.id)"
            items.append(VeyraRibbonItem(
                id: upcomingID, icon: "calendar",
                label: item.kind == .movie ? "FILM BINNENKORT" : "VOLGENDE AFLEVERING",
                text: item.title, detail: detail, contentKind: .upcoming, priority: airingSoon ? 75 : 40, time: item.airDate,
                logoURL: item.logoURL, backdropURL: item.backdropURL,
                tmdbID: item.tmdbID, isMovie: item.kind == .movie,
                reason: airingSoon ? .startsSoon : .upcoming,
                reasonText: airingSoon ? "Begint over \(Int(minutesUntilAiring)) min" : nil,
                onDismiss: { VeyraNowSettingsStore.dismiss(upcomingID) },
                onSnooze: { VeyraNowSettingsStore.snoozeForToday(upcomingID) },
                action: { onToggleReminder(item, !model.home.reminderIDs.contains(item.id)) }))
        }

        // Favorieten eerst; zonder favorieten gewoon alle actieve zenders. Niet
        // steeds dezelfde (laagst genummerde) zender tonen -- roteert elke 5
        // minuten door de kandidaten, en slaat weggetikte zenders gewoon over.
        let liveCandidates = {
            let favorites = model.liveRows(at: now, limit: 6, favoritesOnly: true)
            let base = favorites.isEmpty ? model.liveRows(at: now, limit: 6, favoritesOnly: false) : favorites
            return base.filter { !nowSettings.isHidden("ribbon-live-\($0.id)", now: now) }
        }()
        if !liveCandidates.isEmpty {
            let bucket = Int(now.timeIntervalSince1970 / 300)
            let row = liveCandidates[bucket % liveCandidates.count]
            let justStarted = row.progress < 0.1
            let liveID = "ribbon-live-\(row.id)"
            items.append(VeyraRibbonItem(
                id: liveID, icon: "dot.radiowaves.left.and.right", label: "LIVE NU",
                text: row.title, detail: "nog \(row.remainingMinutes) min", isLive: true, contentKind: .live,
                priority: justStarted ? 85 : (row.isSports ? 65 : 55), time: now, logoURL: row.logoURL,
                backdropURL: row.backdropURL,
                reason: .live, reasonText: "Nu live",
                onDismiss: { VeyraNowSettingsStore.dismiss(liveID) },
                onSnooze: { VeyraNowSettingsStore.snoozeForToday(liveID) },
                action: { onPlayChannel(row.channelID) }))
        }

        if layout.showSport, let sportModel {
            let candidates = ([sportModel.featured(at: now)].compactMap { $0 }
                + sportModel.fixtures(at: now, limit: 5, excluding: sportModel.featured(at: now)?.id))
            if let event = candidates.first(where: { !nowSettings.isHidden("ribbon-sport-\($0.id)", now: now) }) {
                let live = event.isLive(at: now)
                let remaining = event.remainingMinutes(at: now) ?? .max
                let nearEnd = live && remaining <= 20
                // "Straks" is alleen gepast vlak vóór de aftrap -- een wedstrijd die pas over
                // dagen begint krijgt de echte datum, niet een misleidend "straks".
                let minutesUntilStart = event.start.timeIntervalSince(now) / 60
                let startsSoon = !live && minutesUntilStart > 0 && minutesUntilStart <= 180
                let dateText = event.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(VeyraHomeFormat.locale))
                let timeText = event.start.formatted(.dateTime.hour().minute().locale(VeyraHomeFormat.locale))
                let startText = startsSoon ? "Start \(timeText)" : "\(dateText) · \(timeText)"
                let sportID = "ribbon-sport-\(event.id)"
                items.append(VeyraRibbonItem(
                    id: sportID, icon: "sportscourt",
                    label: live ? "SPORT · LIVE" : (startsSoon ? "SPORT · STRAKS" : "SPORT"),
                    text: event.title,
                    detail: live ? "Live op \(event.channelName)" : "\(startText) · \(event.channelName)",
                    isLive: live, contentKind: .sport,
                    priority: nearEnd ? 100 : (live ? 90 : 60), time: live ? now : event.start,
                    logoURL: event.homeLogoURL, secondaryLogoURL: event.awayLogoURL, scoreText: live ? event.score?.text : nil,
                    backdropURL: event.backdropURL, leagueLogoURL: SportsLeague.logo(forCompetition: event.competition, fallback: event.leagueLogoURL),
                    reason: live ? .live : (startsSoon ? .startsSoon : .upcoming),
                    reasonText: live ? "Nu live" : (startsSoon ? "Begint over \(Int(minutesUntilStart)) min" : nil),
                    onDismiss: { VeyraNowSettingsStore.dismiss(sportID) },
                    onSnooze: { VeyraNowSettingsStore.snoozeForToday(sportID) },
                    action: { onPlaySport(event, .live) }))
            }
        }

        // Nieuw uitgebracht (TMDB): een extra bron naast wat de kijker zelf al aan het kijken/
        // volgen is -- de meest recente, nog niet weggetikte film of serie, als de gebruiker
        // dit blok niet uitzette.
        if nowSettings.showReleases {
            // Films en series om-en-om ingevlochten (i.p.v. simpelweg samen op releasedatum
            // gesorteerd) zodat de rotatie hieronder niet kan verzanden in louter films als
            // die toevallig vaker/recenter uitkomen -- series blijven zo altijd aan bod komen.
            let sortedFilms = model.releaseFilms.sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
            let sortedSeries = model.releaseSeries.sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
            var releases: [(BentoTMDBTitle, String)] = []
            for index in 0..<max(sortedFilms.count, sortedSeries.count) {
                if index < sortedFilms.count { releases.append((sortedFilms[index], "Film")) }
                if index < sortedSeries.count { releases.append((sortedSeries[index], "Serie")) }
            }
            // Niet altijd dezelfde titel: roteert nu om de paar minuten door de meest recente,
            // nog niet weggetikte releases (was: 1x per dag) zodat je bij normaal scrollen/
            // terugkeren merkbaar meer variatie ziet, films en series inbegrepen.
            let pool = Array(releases.filter { !nowSettings.isHidden("ribbon-release-\($0.0.id)", now: now) }.prefix(16))
            if !pool.isEmpty {
                let rotationBucket = Int(now.timeIntervalSinceReferenceDate / (4 * 60))
                let (title, kindLabel) = pool[((rotationBucket % pool.count) + pool.count) % pool.count]
                let releaseID = "ribbon-release-\(title.id)"
                items.append(VeyraRibbonItem(
                    id: releaseID, icon: "sparkles", label: "NIEUW UITGEBRACHT",
                    text: title.title, detail: kindLabel, contentKind: .release, priority: 45,
                    backdropURL: title.backdropURL ?? title.posterURL,
                    tmdbID: title.id, isMovie: kindLabel == "Film",
                    // Geen reasonText hier -- het label "NIEUW UITGEBRACHT" zegt al waarom dit
                    // item op de rail staat, een tweede regel met dezelfde tekst is dubbelop.
                    reason: .newRelease,
                    // Zonder échte backdrop valt dit terug op de poster, en die heeft de titel al
                    // ingebakken in de afbeelding -- `titleBakedIntoArt` zorgt dat de kaart daar
                    // dan geen eigen logo/titel nog eens overheen zet (zie `posterContent`).
                    titleBakedIntoArt: title.backdropURL == nil,
                    onDismiss: { VeyraNowSettingsStore.dismiss(releaseID) },
                    onSnooze: { VeyraNowSettingsStore.snoozeForToday(releaseID) },
                    action: { onOpenTMDBTitle(title) }))
            }
        }

        return items
    }

    private func heroHeight(availableHeight: CGFloat) -> CGFloat {
        // iPhone behoudt de huidige maat, ook wanneer een groot toestel
        // tijdelijk een regular size class krijgt. Op iPad en Mac blijft
        // onder de hero ruimte over voor de eerste inhoudsrij.
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom != .pad {
            return heroSpotlight.settings.style == .fullscreen ? 560 : 460
        }
        #endif

        if heroSpotlight.settings.style == .fullscreen {
            return min(620, max(390, availableHeight * 0.72))
        }
        return min(500, max(340, availableHeight * 0.58))
    }

    // MARK: Raster

    @ViewBuilder
    private func bentoTop(now: Date, contentWidth: CGFloat) -> some View {
        // "Binnenkort" teruggezet als vaste rasterrij naast "Verder kijken" (op
        // uitdrukkelijk verzoek teruggedraaid uit de losse Calendar Horizon-sectie
        // van Stap 12 -- weer gewoon één rij, zoals voorheen).
        let today = showUpcoming ? model.today(at: now, limit: Int.max) : nil
        let items = showContinueWatching ? model.home.continueItems : []
        let showVolgende = layout.isVisible(.volgende) && !items.isEmpty
        let showVandaag = layout.isVisible(.vandaag) && today != nil
        #if os(iOS)
        let cardLayout = VeyraCaptionedCardLayout.landscape(
            width: min(regular ? 380 : 300, contentWidth))
        #else
        let cardLayout: VeyraCaptionedCardLayout = .regular
        #endif

        if showVolgende || showVandaag {
            let order: [BentoTile] = [showVolgende ? .volgende : nil, showVandaag ? .vandaag : nil].compactMap { $0 }
            let baseProfile = BentoProfile.make(regular ? .tablet : .phone, order: order)
            // De 16:9-kaarten hebben meer hoogte nodig dan de vroegere brede banners.
            let rowHeight = max(baseProfile.rowHeights.first ?? 0, cardLayout.height + 32)
            let profile = BentoProfile(columns: baseProfile.columns,
                                       rowHeights: Array(repeating: rowHeight, count: baseProfile.rowHeights.count),
                                       spacing: baseProfile.spacing, cells: baseProfile.cells)

            VeyraBentoGrid(profile: profile) {
                if showVolgende {
                    VStack(alignment: .leading, spacing: 10) {
                        // Subtiele titel boven de rij, i.p.v. los per tegel. Zelfde cyaan
                        // lijnstijl achter de titel als `VeyraHomeSectionHeader`/de tijdlijn
                        // onder "Veyra Now", voor een consistent beeld over heel Home.
                        HStack(spacing: 8) {
                            Text("Verder kijken (\(items.count))")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))
                            VeyraSectionTitleLine(height: 1.5)
                        }

                        ScrollView(.horizontal) {
                            // .top i.p.v. de standaard .center: anders komt de rij verticaal
                            // gecentreerd te staan in de (soms hogere) rasterrij, wat een groter
                            // gat tussen titel en kaart geeft dan bij "Favorieten"/"College
                            // football" in de Sport-sectie (die wél .top gebruikt).
                            LazyHStack(alignment: .top, spacing: 10) {
                                // "Resume Flow": het meest relevante item krijgt een bredere,
                                // filmische kaart met backdrop/clearlogo/voortgangslijn -- zelfde
                                // rijhoogte als de rest, dus de rest van het raster blijft gelijk.
                                if let hero = items.first {
                                    Button { onPlay(hero) } label: {
                                        VeyraBentoContinueHeroContent(item: hero, compact: true, showLabel: false)
                                            .clipShape(VeyraRadius.posterShape)
                                            .overlay(VeyraRadius.posterShape.strokeBorder(VeyraFrame.active, lineWidth: 1.5))
                                            .shadow(color: VeyraColors.cyan.opacity(0.22), radius: 14, x: -2, y: 3)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        if hero.playbackID != nil {
                                            Button(role: .destructive) { Task { await model.home.remove(hero) } } label: {
                                                Label("Verwijder uit Verder kijken", systemImage: "xmark.circle")
                                            }
                                        }
                                    }
                                    .frame(width: cardLayout.width * 1.5, height: cardLayout.height)
                                }
                                ForEach(items.dropFirst()) { item in
                                    continueButton(item, radius: 16) {
                                        VeyraBentoContinueMiniContent(item: item, compact: true,
                                                                      cornerRadius: 16, cardLayout: cardLayout)
                                    }
                                    .frame(width: cardLayout.width, height: cardLayout.height)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    .bentoCell(profile.cell(.volgende))
                }

                if showVandaag, let today {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("Binnenkort")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))
                            VeyraSectionTitleLine(height: 1.5)
                        }

                        ScrollView(.horizontal) {
                            LazyHStack(alignment: .top, spacing: 10) {
                                ForEach(today.items) { item in
                                    let on = model.home.reminderIDs.contains(item.id)
                                    Button { toggle(item) } label: {
                                        VeyraBentoUpcomingCardContent(item: item, now: now, isReminded: on,
                                                                      compact: true, cornerRadius: 16,
                                                                      cardLayout: cardLayout)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: cardLayout.width, height: cardLayout.height)
                                    .contextMenu {
                                        Button { toggle(item) } label: {
                                            Label(on ? "Herinnering uit · \(item.title)" : "Herinner mij · \(item.title)",
                                                  systemImage: on ? "bell.slash" : "bell")
                                        }
                                    }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    .bentoCell(profile.cell(.vandaag))
                    .sensoryFeedback(.selection, trigger: model.home.reminderIDs)
                }
            }
        }
    }

    // MARK: Sports Stage (Live Sport)

    @ViewBuilder
    private func bentoSportsStage(now: Date) -> some View {
        if layout.showSport, let sportModel, let featured = sportModel.liveEvents(at: now).first {
            VeyraSportsStage(event: featured, now: now) {
                onPlaySport(featured, .live)
            }
        }
    }

    // MARK: Compacte streamingdiensten onder de navigatie (iPhone, iPad, Mac)

    private var showsStreamingRibbon: Bool {
        layout.isVisible(.streaming) && !model.providers.isEmpty
    }

    @ViewBuilder
    private var streamingRibbon: some View {
        if showsStreamingRibbon {
            ScrollView(.horizontal) {
                LazyHStack(spacing: regular ? 12 : 8) {
                    ForEach(model.providers) { provider in
                        Button { onOpenCatalog(provider) } label: {
                            VeyraLogoShelfTile(name: provider.name, iconURL: provider.imageURL,
                                              wideURL: provider.wideURL, brand: provider.brand,
                                              compact: true, customURL: provider.customLogoURL, ribbon: true)
                                .frame(width: regular ? 140 : 112, height: regular ? 56 : 48)
                        }
                        .buttonStyle(VeyraStreamingInteractionStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(height: regular ? 72 : 64)
            .frame(maxWidth: .infinity)
            .scrollIndicators(.hidden)
            .veyraHomeTileMenu(.streaming)
            .accessibilityLabel("Streamingdiensten")
        }
    }

    // MARK: Raster — Live TV

    /// Losstaand van de @ViewBuilder-functie hieronder: `Set.insert` retourneert een tuple, wat de
    /// ViewBuilder in de war brengt als het als een `if`-conditie binnenin een view-body staat.
    private func middlePresentTiles(live: [BentoLiveRow]) -> Set<BentoTile> {
        var present = Set<BentoTile>()
        if layout.isVisible(.live), !live.isEmpty { present.insert(.live) }
        return present
    }

    @ViewBuilder
    private func bentoMiddle(now: Date, contentWidth: CGFloat, tiles: Set<BentoTile>) -> some View {
        // iPad/macOS (`regular`) krijgt, net als tvOS, 8 zenders in twee kolommen van 4 naast
        // elkaar i.p.v. één kolom van 4 -- er is daar toch al de volle breedte beschikbaar
        // (`.live` krijgt die als enige tegel in deze rij, zie `BentoProfile.make`).
        let live = tiles.contains(.live)
            ? model.liveRows(at: now, limit: regular ? 8 : 4, recentFirst: true, favoritesOnly: liveFavoritesOnly)
            : []
        let present = middlePresentTiles(live: live).intersection(tiles)
        let order = layout.orderedTiles.filter { present.contains($0) }
        let profile = BentoProfile.make(regular ? .tablet : .phone, order: order)

        if !present.isEmpty {
            VeyraBentoGrid(profile: profile) {
                if present.contains(.live) {
                    VeyraBentoLiveList(compact: true) {
                        if regular {
                            HStack(alignment: .top, spacing: 14) {
                                liveColumn(Array(live.prefix(4)))
                                liveColumn(Array(live.dropFirst(4).prefix(4)))
                            }
                        } else {
                            ForEach(live) { row in
                                Button { onPlayChannel(row.channelID) } label: {
                                    VeyraBentoLiveRowContent(row: row, compact: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .veyraHomeTileMenu(.live)
                    .bentoCell(profile.cell(.live))
                }

            }
        }
    }

    /// Eén kolom van maximaal 4 zenders, voor de iPad/macOS "Live nu" naast-elkaar-weergave
    /// (zelfde opbouw als `liveColumn` op tvOS in `VeyraBentoHome.swift`, maar zonder focus-
    /// afhandeling, die daar tvOS-specifiek is).
    @ViewBuilder
    private func liveColumn(_ rows: [BentoLiveRow]) -> some View {
        VStack(spacing: 7) {
            ForEach(rows) { row in
                Button { onPlayChannel(row.channelID) } label: {
                    VeyraBentoLiveRowContent(row: row, compact: true)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: Raster — IPTV: films · series (na Sport & Filmcollecties)

    /// Losstaand, om dezelfde reden als `middlePresentTiles` hierboven.
    private func iptvPresentTiles() -> Set<BentoTile> {
        var present = Set<BentoTile>()
        if layout.isVisible(.iptvFilms), !model.iptvFilms.isEmpty { present.insert(.iptvFilms) }
        if layout.isVisible(.iptvSeries), !model.iptvSeries.isEmpty { present.insert(.iptvSeries) }
        return present
    }

    @ViewBuilder
    private func bentoIPTV(now: Date) -> some View {
        let present = iptvPresentTiles()
        let order = layout.orderedTiles.filter { present.contains($0) }
        let profile = BentoProfile.make(regular ? .tablet : .phone, order: order)

        VeyraBentoGrid(profile: profile) {
            if present.contains(.iptvFilms) {
                VeyraBentoShelf(title: "IPTV films", subtitle: "Nieuw toegevoegd", compact: true) {
                    ForEach(model.iptvFilms) { film in
                        Button { onOpenIPTVFilm(film) } label: {
                            VeyraBentoPosterContent(title: film.name, url: film.posterURL,
                                                    compact: true, kind: .movie, sourceLabel: film.providerName)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .veyraHomeTileMenu(.iptvFilms)
                .bentoCell(profile.cell(.iptvFilms))
            }

            if present.contains(.iptvSeries) {
                VeyraBentoShelf(title: "IPTV series", subtitle: "Nieuw toegevoegd", compact: true) {
                    ForEach(model.iptvSeries) { series in
                        Button { onOpenIPTVSeries(series) } label: {
                            VeyraBentoPosterContent(title: series.name, url: series.coverURL,
                                                    compact: true, kind: .episode, sourceLabel: series.providerName)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .veyraHomeTileMenu(.iptvSeries)
                .bentoCell(profile.cell(.iptvSeries))
            }
        }
    }

    // MARK: Nieuw van hier (Regional Releases) — iOS/iPadOS

    private static let regionalReleaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_BE")
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    private func regionalReleaseLabel(_ event: RegionalReleaseEvent) -> String {
        let date = Self.regionalReleaseDateFormatter.string(from: event.releaseDate)
        switch event.releaseType {
        case .newSeries: return "Nieuwe reeks • \(date)"
        case .newSeason:
            if let season = event.season { return "Seizoen \(season) • \(date)" }
            return "Nieuw seizoen • \(date)"
        case .premiere: return "Première • \(date)"
        case .upcomingPremiere: return "Binnenkort • \(date)"
        case .episode: return date
        }
    }

    @ViewBuilder
    private func bentoRegional(now: Date) -> some View {
        let events = regionalReleasesForNieuwVanHier()
        if layout.isVisible(.nieuwVanHier), !events.isEmpty {
            VeyraBentoShelf(title: "Nieuw van hier", subtitle: "Regionale releases", compact: true) {
                ForEach(events) { event in
                    Button {
                        // Spec §6/§33: Regional Releases levert enkel media-identiteit/discovery;
                        // het openen gebeurt via dezelfde route als de bestaande TMDB-planken,
                        // net als op tvOS (`bentoRegional` in VeyraBentoHome.swift).
                        guard let tmdbID = event.tmdbID else { return }
                        onOpenTMDBTitle(BentoTMDBTitle(id: tmdbID, kind: .episode, title: event.title, posterURL: nil))
                    } label: {
                        VeyraBentoPosterContent(
                            title: event.title,
                            url: TMDBImageURLBuilder.poster(event.posterPath),
                            compact: true,
                            kind: .episode,
                            sourceLabel: regionalReleaseLabel(event)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .veyraHomeTileMenu(.nieuwVanHier)
        }
    }

    /// Zelfde dedupe-regel als de tvOS-tegenhanger (`regionalReleasesForNieuwVanHier` in
    /// VeyraBentoHome.swift) -- bewust hier opnieuw, niet gedeeld, omdat de hele tvOS-Home-file
    /// achter `#if os(tvOS)` zit en dus niet beschikbaar is om vanuit deze iOS-file aan te roepen.
    private func regionalReleasesForNieuwVanHier() -> [RegionalReleaseEvent] {
        guard showContinueWatching || showUpcoming else { return model.regionalReleases }
        var handledTMDBIDs: Set<Int> = []
        if showContinueWatching {
            handledTMDBIDs.formUnion(model.home.continueItems.compactMap(\.tmdbID))
        }
        if showUpcoming {
            handledTMDBIDs.formUnion(model.home.upcoming.compactMap(\.tmdbID))
        }
        guard !handledTMDBIDs.isEmpty else { return model.regionalReleases }
        return model.regionalReleases.filter { event in
            guard let tmdbID = event.tmdbID else { return true }
            return !handledTMDBIDs.contains(tmdbID)
        }
    }

    private func reloadLayout() {
        let fresh = VeyraHomeLayoutStore.load()
        if fresh != layout { layout = fresh }
    }

    private func cell<Content: View>(action: @escaping () -> Void, @ViewBuilder label: () -> Content) -> some View {
        Button(action: action) { label() }
            .buttonStyle(VeyraPressStyle())
    }

    private func continueButton<Content: View>(_ item: ContinueItem, radius: CGFloat = 22,
                                               @ViewBuilder label: () -> Content) -> some View {
        // .plain i.p.v. VeyraPressStyle: die laatste tekent zelf nog een kader/achtergrond rond de
        // VOLLEDIGE label (dus ook rond de meta-tekst onder de afbeelding), wat een zichtbaar dubbel
        // kader gaf boven op de rand die VeyraBentoContinueMiniContent al om enkel de afbeelding tekent.
        Button { onPlay(item) } label: { label() }
            .buttonStyle(.plain)
            .contextMenu {
                if item.playbackID != nil {
                    Button(role: .destructive) { Task { await model.home.remove(item) } } label: {
                        Label("Verwijder uit Verder kijken", systemImage: "xmark.circle")
                    }
                }
            }
    }

    private func toggle(_ item: UpcomingItem) {
        let on = model.home.toggleReminder(item)
        onToggleReminder(item, on)
    }

    private func play(_ suggestion: BentoTimeSuggestion) {
        switch suggestion.target {
        case .resume(let item): onPlay(item)
        case .live(let channelID, _): onOpenLiveTV(channelID)
        }
    }

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f
    }()

    private static let rawDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

#if DEBUG
#Preview("Bento iPhone") {
    VeyraBentoHomeView(model: VeyraBentoViewModel.preview(),
                       sportModel: VeyraSportViewModel(provider: MockSportProvider()),
                       onPlay: { _ in })
        .preferredColorScheme(.dark)
}
#endif

#endif
