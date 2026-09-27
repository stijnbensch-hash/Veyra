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

    var onPlay: (ContinueItem) -> Void
    var onToggleReminder: (UpcomingItem, Bool) -> Void
    var onOpenLiveTV: (String?) -> Void
    var onPlayChannel: (String) -> Void
    var onOpenIPTVFilm: (IPTVVODItem) -> Void
    var onOpenIPTVSeries: (XtreamSeriesItem) -> Void
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
    @AppStorage(VeyraCollectionNames.key) private var showCollectionNames = true
    @AppStorage(GeneralSettingsDefaults.showUpcomingKey) private var showUpcoming = true
    @State private var layout = VeyraHomeLayoutStore.load()
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
         onOpenIPTVFilm: @escaping (IPTVVODItem) -> Void = { _ in },
         onOpenIPTVSeries: @escaping (XtreamSeriesItem) -> Void = { _ in },
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
        GeometryReader { rootGeo in
            // Beschikbare breedte binnen de zijmarge (.padding(.horizontal, 16) hieronder, dus 2x 16pt eraf),
            // zodat de horizontaal scrollende rijen hun vaste kaartbreedtes hierop kunnen clampen en NOOIT
            // breder worden dan het scherm — op elk toestel, ook grotere iPhones die per ongeluk `regular` zijn.
            let contentWidth = max(rootGeo.size.width - 32, 0)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if showsHero {
                        // Zoek-/instellingenknop zweven over de hero (net als in Strand) i.p.v.
                        // in een eigen balk erboven -- de hero zelf loopt door tot onder de
                        // statusbalk, de knoppen blijven wel binnen de safe area staan.
                        ZStack(alignment: .top) {
                            hero(availableHeight: rootGeo.size.height)
                            if floatingButtons {
                                HStack {
                                    FloatingIconButton(symbol: "magnifyingglass", accessibilityLabel: "Zoeken", action: onSearch)
                                    Spacer()
                                    if showsSettings {
                                        FloatingIconButton(symbol: "gearshape.fill", accessibilityLabel: "Instellingen", action: onSettings)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, floatingButtonTopPadding)
                            }
                        }
                    } else if floatingButtons {
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

                    VStack(alignment: .leading, spacing: 32) {
                        if let message = model.home.notice {
                            VeyraStatusMessage(text: message) { Task { await model.load(force: true) } }
                        }

                        // "Verder kijken" en "Binnenkort" helemaal bovenaan, net als op tvOS.
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            bentoTop(now: context.date, contentWidth: contentWidth)
                        }

                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            bentoMiddle(now: context.date, contentWidth: contentWidth)
                        }
                        .padding(.top, -14)

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

                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            bentoBottom(now: context.date, contentWidth: contentWidth)
                        }

                        // "IPTV films"/"IPTV series" pas na Sport & Filmcollecties, net als op tvOS.
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            bentoIPTV(now: context.date)
                        }

                        if layout.showShelves { VeyraBentoUserShelves(compact: true, onOpen: onOpenTMDBTitle) }
                    }
                    .padding(.horizontal, 16)
                    // Een kleine afstand tussen de hero en de eerste rij.
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)
            #if os(iOS)
            // Het volledige hero-beeld, inclusief de statusbalkzone, schuift nu
            // als onderdeel van de pagina weg in plaats van vast te blijven staan.
            .ignoresSafeArea(edges: showsHero && heroSpotlight.settings.style == .fullscreen ? .top : [])
            #endif
            .refreshable {
                await model.load(force: true)
                await sportModel?.load()
            }
            .task { await model.load() }
            .onChange(of: catalogLanguages) { _, _ in Task { await model.load(force: true) } }
            .onReceive(NotificationCenter.default.publisher(for: .veyraHomeLayoutDidChange)) { _ in reloadLayout() }
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
        .background(VeyraHomeStyle.ink.ignoresSafeArea())
    }

    private var floatingButtonTopPadding: CGFloat {
        #if os(iOS)
        showsHero && heroSpotlight.settings.style == .fullscreen ? VeyraSafeArea.top + 8 : 8
        #else
        8
        #endif
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
                                   height: heroHeight(availableHeight: availableHeight),
                                   onIndexChange: { heroSpotlight.currentIndex = $0 })
                .padding(.horizontal, heroSpotlight.settings.style == .card ? 16 : 0)
        } else if model.home.phase == .loading || model.home.phase == .idle {
            ProgressView().tint(.white).frame(maxWidth: .infinity).frame(height: 240)
        }
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
        // "Binnenkort" toont alles wat Trakt teruggeeft, net als op tvOS.
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
                        // Subtiele titel boven de rij, i.p.v. los per tegel.
                        Text("Verder kijken")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))

                        ScrollView(.horizontal) {
                            // .top i.p.v. de standaard .center: anders komt de rij verticaal
                            // gecentreerd te staan in de (soms hogere) rasterrij, wat een groter
                            // gat tussen titel en kaart geeft dan bij "Favorieten"/"College
                            // football" in de Sport-sectie (die wél .top gebruikt).
                            LazyHStack(alignment: .top, spacing: 10) {
                                ForEach(items) { item in
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
                        Text("Binnenkort")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))

                        // Losse kaarten op een horizontale rij, zonder groot kader eromheen.
                        ScrollView(.horizontal) {
                            // .top, zelfde reden als bij "Verder kijken" hierboven.
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
                        .sensoryFeedback(.selection, trigger: model.home.reminderIDs)
                    }
                    .veyraHomeTileMenu(.vandaag)
                    .bentoCell(profile.cell(.vandaag))
                }
            }
        }
    }

    // MARK: Raster — midden: Live nu · Streamingdiensten

    /// Losstaand van de @ViewBuilder-functie hieronder: `Set.insert` retourneert een tuple, wat de
    /// ViewBuilder in de war brengt als het als een `if`-conditie binnenin een view-body staat.
    private func middlePresentTiles(live: [BentoLiveRow]) -> Set<BentoTile> {
        var present = Set<BentoTile>()
        if layout.isVisible(.live), !live.isEmpty { present.insert(.live) }
        if layout.isVisible(.streaming), !model.providers.isEmpty { present.insert(.streaming) }
        return present
    }

    @ViewBuilder
    private func bentoMiddle(now: Date, contentWidth: CGFloat) -> some View {
        let live = model.liveRows(at: now, limit: 4, recentFirst: true)
        let present = middlePresentTiles(live: live)
        let order = layout.orderedTiles.filter { present.contains($0) }
        let baseProfile = BentoProfile.make(regular ? .tablet : .phone, order: order)
        #if os(iOS)
        // Wanneer Streamingdiensten vóór Live nu staat, krijgt de ruimte
        // eronder dezelfde maat als de ruimte erboven. De extra rijafstand
        // vergroot ook het raster, zodat Sport en alle volgende secties
        // netjes mee omlaag schuiven.
        let rowSpacing: CGFloat = order == [.streaming, .live] ? 32 : baseProfile.spacing
        #else
        let rowSpacing = baseProfile.spacing
        #endif
        let profile = BentoProfile(columns: baseProfile.columns,
                                   rowHeights: baseProfile.rowHeights,
                                   spacing: rowSpacing,
                                   cells: baseProfile.cells)

        VeyraBentoGrid(profile: profile) {
            if present.contains(.live) {
                VeyraBentoLiveList(compact: true) {
                    ForEach(live) { row in
                        Button { onPlayChannel(row.channelID) } label: {
                            VeyraBentoLiveRowContent(row: row, compact: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .veyraHomeTileMenu(.live)
                .bentoCell(profile.cell(.live))
            }

            if present.contains(.streaming) {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(model.providers) { provider in
                            Button { onOpenCatalog(provider) } label: {
                                VeyraBentoStreamingContent(name: provider.name, iconURL: provider.imageURL,
                                                           wideURL: provider.wideURL, brand: provider.brand, compact: true,
                                                           customURL: provider.customLogoURL)
                            }
                            .buttonStyle(.plain)
                            .frame(width: min(regular ? 190 : 150, contentWidth), height: regular ? 76 : 60)
                        }
                    }
                    // minWidth: contentWidth + center -- als de logo's samen smaller zijn dan het blok
                    // (weinig diensten) staan ze gecentreerd, net als de andere kaders; passen ze niet,
                    // dan scrollt de rij gewoon zoals voorheen (geen kap op het aantal diensten).
                    .frame(minWidth: contentWidth, maxHeight: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .veyraHomeTileMenu(.streaming)
                .bentoCell(profile.cell(.streaming))
            }
        }
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
                            VeyraBentoPosterContent(title: film.name, url: film.posterURL, compact: true, kind: .movie)
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
                            VeyraBentoPosterContent(title: series.name, url: series.coverURL, compact: true, kind: .episode)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .veyraHomeTileMenu(.iptvSeries)
                .bentoCell(profile.cell(.iptvSeries))
            }
        }
    }

    // MARK: Raster — onder: Filmcollecties (na Sport)

    @ViewBuilder
    private func bentoBottom(now: Date, contentWidth: CGFloat) -> some View {
        if layout.isVisible(.collecties), !model.collections.isEmpty {
            let profile = BentoProfile.make(regular ? .tablet : .phone, order: [.collecties])

            VeyraBentoGrid(profile: profile) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Filmcollecties")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))

                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 10) {
                            ForEach(model.collections) { collection in
                                Button { onOpenCatalog(collection) } label: {
                                    VeyraBentoCollectionMiniContent(title: collection.name, url: collection.imageURL, compact: true, showName: showCollectionNames)
                                }
                                .buttonStyle(.plain)
                                .frame(width: min(regular ? 385 : 298, contentWidth), height: (regular ? 180 : 141) + (showCollectionNames ? 22 : 0))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                // Even veel ruimte boven en onder de banners (in het blok zelf en in de blokhoogte), zodat ze
                // gecentreerd tussen de kaders staan, ook wanneer het blok verplaatst wordt.
                .padding(.vertical, 8)
                .veyraHomeTileMenu(.collecties)
                .bentoCell(profile.cell(.collecties))
            }
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
