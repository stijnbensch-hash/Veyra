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

struct VeyraBentoHomeView: View {
    @State private var model: VeyraBentoViewModel
    private let sportModel: VeyraSportViewModel?

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
                    if floatingButtons {
                        HStack {
                            FloatingIconButton(symbol: "magnifyingglass", accessibilityLabel: "Zoeken", action: onSearch)
                            Spacer()
                            if showsSettings {
                                FloatingIconButton(symbol: "gearshape.fill", accessibilityLabel: "Instellingen", action: onSettings)
                            }
                        }
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
                    // De zoek-/instellingenknoppen staan nu als vaste (niet-zwevende) balk boven deze
                    // ScrollView (zie HomeView.swift), die zelf al de safe-area/statusbalk-ruimte
                    // reserveert -- hier is dus enkel nog een gewone, kleine top-marge nodig.
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)
            .background(VeyraHomeStyle.ink.ignoresSafeArea())
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
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(120))
                    if Task.isCancelled { break }
                    await model.refreshLive()
                    if let sportModel, sportModel.events.isEmpty { await sportModel.reload() }
                }
            }
        }
    }

    @ViewBuilder
    private var hero: some View {
        if showContinueWatching, let first = model.continueMain {
            VeyraHeroView(content: model.home.heroContent(forContinue: first),
                          height: regular ? 520 : 420,
                          onPlay: { _ in onPlay(first) },
                          onInfo: { _ in })
        } else if model.home.phase == .loading || model.home.phase == .idle {
            ProgressView().tint(.white).frame(maxWidth: .infinity).frame(height: 240)
        } else {
            Color.clear.frame(height: 24)
        }
    }

    // MARK: Raster

    @ViewBuilder
    private func bentoTop(now: Date, contentWidth: CGFloat) -> some View {
        // "Binnenkort" toont alles wat Trakt teruggeeft, net als op tvOS.
        let today = showUpcoming ? model.today(at: now, limit: Int.max) : nil
        let items = showContinueWatching ? model.home.continueItems : []
        let showVolgende = layout.isVisible(.volgende) && !items.isEmpty
        let showVandaag = layout.isVisible(.vandaag) && today != nil

        if showVolgende || showVandaag {
            let order: [BentoTile] = [showVolgende ? .volgende : nil, showVandaag ? .vandaag : nil].compactMap { $0 }
            let profile = BentoProfile.make(regular ? .tablet : .phone, order: order)

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
                            HStack(spacing: 10) {
                                ForEach(items) { item in
                                    continueButton(item, radius: 16) { VeyraBentoContinueMiniContent(item: item, compact: true) }
                                        .frame(width: min(regular ? 380 : 300, contentWidth), height: regular ? 168 : 130)
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
                            HStack(spacing: 10) {
                                ForEach(today.items) { item in
                                    let on = model.home.reminderIDs.contains(item.id)
                                    Button { toggle(item) } label: {
                                        VeyraBentoUpcomingCardContent(item: item, now: now, isReminded: on, compact: true)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: min(regular ? 380 : 300, contentWidth), height: regular ? 168 : 130)
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
        let profile = BentoProfile.make(regular ? .tablet : .phone, order: order)

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
                    HStack(spacing: 10) {
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
                        HStack(spacing: 10) {
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
