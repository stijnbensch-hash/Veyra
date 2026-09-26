// VeyraBentoHome.swift — tvOS 17+
// De bento-home: hero + één raster van zes tegels (Verder kijken · Live nu · Vandaag · Tijd voor jou ·
// Nieuw toegevoegd · Bronnen), met daaronder optioneel de sectie Sport.
//
//   rust (geen focus / Verder kijken)  grote hero (660 pt) met "nu" en "straks"
//   focus op een andere tegel          hero klapt in tot een kopregel (300 pt) die volgt wat je focust:
//                                      Live nu -> de live zender (sport eerst), Vandaag -> de eerste release
//
// Bediening:
//   select Verder kijken   -> afspelen (lang indrukken: verwijderen uit Verder kijken)
//   select Live nu         -> onOpenLiveTV(zenderID)
//   select Vandaag         -> herinnering aan/uit (lang indrukken: per titel)
//   select Tijd voor jou   -> eerste suggestie afspelen (lang indrukken: alle suggesties)
//   select Nieuw / Bronnen -> onOpenNew() / onOpenSources()
//
// Vereist: VeyraBentoLayout/Model/Tiles.swift, VeyraBentoFocus.swift (VeyraHomeFocus, VeyraTileStyle),
//          VeyraBentoStyle.swift, VeyraBentoTrakt.swift, VeyraBentoHero.swift, VeyraBentoHeroModel.swift, VeyraBentoEPGModel.swift,
//          en voor Sport: VeyraSportHome/Shared/Section.swift.

#if os(tvOS)
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

    @AppStorage(GeneralSettingsDefaults.showContinueWatchingKey) private var showContinueWatching = true
    @AppStorage(TMDBCatalogLanguageFilter.key) private var catalogLanguages = "nl-en"
    @AppStorage(GeneralSettingsDefaults.showUpcomingKey) private var showUpcoming = true
    @State private var layout = VeyraHomeLayoutStore.load()
    @AppStorage(VeyraCollectionNames.key) private var showCollectionNames = true
    @State private var askPreset = false

    @FocusState private var focus: VeyraHomeFocus?

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
         onOpenCompetition: @escaping (SportCompetition) -> Void = { _ in }) {
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
    }

    // MARK: Hero

    private var heroCollapsed: Bool {
        switch focus {
        case nil, .cont?: return false
        default: return true
        }
    }

    private var heroContent: HeroContent? {
        let now = Date.now
        switch focus {
        case .cont(let id)?:
            if showContinueWatching, let item = model.home.continueItems.first(where: { $0.id == id }) {
                return model.home.heroContent(forContinue: item)
            }
        case .sport(_, let id)?:
            if let event = sportModel?.events.first(where: { $0.id == id }) { return sportModel?.heroContent(for: event) }
        case .bento(.live)?:
            if let row = model.featuredLiveRow(at: now), let content = model.heroContent(forLive: row, now: now) { return content }
        case .bento(.vandaag)?:
            if showUpcoming, let item = model.today(at: now)?.items.first { return model.home.heroContent(forUpcoming: item) }
        default:
            break
        }
        if showContinueWatching, let first = model.continueMain { return model.home.heroContent(forContinue: first) }
        // Zonder Trakt-items (niet gekoppeld of niets bezig): de live zender als hero.
        if let row = model.featuredLiveRow(at: now) { return model.heroContent(forLive: row, now: now) }
        return nil
    }

    @ViewBuilder
    private var hero: some View {
        if let content = heroContent {
            if heroCollapsed {
                BentoCollapsedHero(content: content)
            } else {
                VeyraHeroView(content: content, onPlay: playFromHero, onInfo: { _ in })
            }
        } else {
            Color.clear
        }
    }

    private func playFromHero(_ moment: HeroMoment) {
        let now = Date.now
        if let item = model.home.continueItems.first(where: { $0.id == moment.id }) {
            onPlay(item)
        } else if let row = model.liveRows(at: now).first(where: { $0.id == moment.id }) {
            onOpenLiveTV(row.channelID)
        } else if let upcoming = model.home.upcoming.first(where: { $0.id == moment.id }) {
            toggle(upcoming)
        } else if let event = sportModel?.events.first(where: { $0.id == moment.id }) {
            if event.isLive(at: now) {
                onPlaySport(event, .live)
            } else {
                onToggleSportReminder(event, sportModel?.toggleReminder(event) ?? false)
            }
        }
    }

    // MARK: Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 48) {
                if let message = model.home.notice {
                    VeyraStatusMessage(text: message) { Task { await model.load(force: true) } }
                }

                // "Verder kijken" en "Binnenkort" helemaal bovenaan, los van de rest van het raster.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    bentoTop(now: context.date)
                }

                TimelineView(.periodic(from: .now, by: 30)) { context in
                    bentoMiddle(now: context.date)
                }

                // Sport onder "Streamingdiensten".
                if layout.showSport, let sportModel, !sportModel.events.isEmpty {
                    SportSection(
                        model: sportModel,
                        focus: $focus,
                        onPlay: onPlaySport,
                        onToggleReminder: onToggleSportReminder,
                        onOpenCompetition: onOpenCompetition)
                } else if layout.showSport, let sportModel, sportModel.phase != .idle, sportModel.phase != .loading {
                    Button { onOpenCompetition(SportCompetition(name: "Sport", liveCount: 0, eventCount: 0, nextStart: nil)) } label: {
                        VeyraStatusMessage(text: "Sport: geen wedstrijden gevonden. Open het Sport-menu.")
                    }
                    .buttonStyle(VeyraTileStyle())
                    .focused($focus, equals: .competition("Sport"))
                }

                TimelineView(.periodic(from: .now, by: 30)) { context in
                    bentoBottom(now: context.date)
                }

                // "IPTV films"/"IPTV series" pas na Sport & Filmcollecties.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    bentoIPTV(now: context.date)
                }

                if layout.showShelves { VeyraBentoUserShelves(onOpen: onOpenTMDBTitle) }
            }
            .padding(.horizontal, 80)
            .padding(.top, 24)
            .padding(.bottom, 80)
        }
        // Overal de effen grijze achtergrond (geen cyaan/rood) -- geen groot
        // team-logo meer als achtergrond bij een gefocuste wedstrijd.
        .background(VeyraPlainBackground())
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .task { await model.load() }
        .onChange(of: catalogLanguages) { _, _ in Task { await model.load(force: true) } }
        .onReceive(NotificationCenter.default.publisher(for: .veyraHomeLayoutDidChange)) { _ in reloadLayout() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in reloadLayout() }
        // Anders blijven "IPTV films"/"IPTV series" de oude, al-in-memory
        // lijst tonen totdat je handmatig ververst of de app herstart, ook
        // als je net iets verborgen hebt bij "VOD beheren".
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

    @ViewBuilder
    private func liveColumn(_ rows: [BentoLiveRow]) -> some View {
        VStack(spacing: 4) {
            ForEach(rows) { row in
                Button { onPlayChannel(row.channelID) } label: {
                    VeyraBentoLiveRowContent(row: row)
                }
                .buttonStyle(VeyraRowStyle())
                .focused($focus, equals: .channel(row.channelID))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: Raster

    @ViewBuilder
    private func bentoTop(now: Date) -> some View {
        // "Binnenkort" toont alles wat Trakt teruggeeft, niet slechts de eerste paar.
        let today = showUpcoming ? model.today(at: now, limit: Int.max) : nil
        let items = showContinueWatching ? model.home.continueItems : []
        let showVolgende = layout.isVisible(.volgende) && !items.isEmpty
        let showVandaag = layout.isVisible(.vandaag) && today != nil

        if showVolgende || showVandaag {
            let order: [BentoTile] = [showVolgende ? .volgende : nil, showVandaag ? .vandaag : nil].compactMap { $0 }
            let profile = BentoProfile.make(.tv, order: order)

            VeyraBentoGrid(profile: profile) {
                if showVolgende {
                    VStack(alignment: .leading, spacing: 4) {
                        // Subtiele titel boven de rij, i.p.v. los per tegel.
                        Text("Verder kijken")
                            .font(.system(size: 20, weight: .bold))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))
                            .padding(.horizontal, 12)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 24) {
                                ForEach(items) { item in
                                    continueButton(item, radius: 22) { VeyraBentoContinueMiniContent(item: item) }
                                        .frame(width: 420, height: 236)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                        }
                        .scrollClipDisabled()
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                    .bentoCell(profile.cell(.volgende))
                }

                if showVandaag, let today {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Binnenkort")
                            .font(.system(size: 20, weight: .bold))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))
                            .padding(.horizontal, 12)

                        // Losse kaarten op een horizontale rij, zonder groot kader eromheen.
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 24) {
                                ForEach(today.items) { item in
                                    let on = model.home.reminderIDs.contains(item.id)
                                    Button { toggle(item) } label: {
                                        VeyraBentoUpcomingCardContent(item: item, now: now, isReminded: on)
                                    }
                                    .buttonStyle(VeyraCaptionedTileStyle())
                                    .focused($focus, equals: .cont("upcoming-\(item.id)"))
                                    .frame(width: 420, height: 236)
                                    .contextMenu {
                                        Button { toggle(item) } label: {
                                            Label(on ? "Herinnering uit · \(item.title)" : "Herinner mij · \(item.title)",
                                                  systemImage: on ? "bell.slash" : "bell")
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                        }
                        .scrollClipDisabled()
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
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
    private func bentoMiddle(now: Date) -> some View {
        let live = model.liveRows(at: now, limit: 8, recentFirst: true)
        let present = middlePresentTiles(live: live)
        let order = layout.orderedTiles.filter { present.contains($0) }
        let profile = BentoProfile.make(.tv, order: order)

        VeyraBentoGrid(profile: profile) {
            if present.contains(.live) {
                // De 8 laatst bekeken zenders in twee kolommen van 4, zodat het blok op zijn vaste hoogte blijft.
                VeyraBentoLiveList {
                    HStack(alignment: .top, spacing: 24) {
                        liveColumn(Array(live.prefix(4)))
                        liveColumn(Array(live.dropFirst(4).prefix(4)))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .bentoCell(profile.cell(.live))
            }

            if present.contains(.streaming) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(model.providers) { provider in
                            Button { onOpenCatalog(provider) } label: {
                                VeyraBentoStreamingContent(name: provider.name, iconURL: provider.imageURL,
                                                           wideURL: provider.wideURL, brand: provider.brand,
                                                           customURL: provider.customLogoURL)
                            }
                            .buttonStyle(VeyraTileStyle(cornerRadius: 26))
                            .focused($focus, equals: .shelf("prov-\(provider.id)"))
                            .frame(width: 300, height: 132)
                        }
                    }
                    .padding(12)
                }
                .scrollClipDisabled()
                // Gecentreerd tussen de kaders, net als de andere rijen -- extra ruimte boven/onder
                // via de grotere tegelhoogte (zie BentoTile.height(.streaming) in VeyraBentoLayout.swift).
                .frame(maxHeight: .infinity, alignment: .center)
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
        let profile = BentoProfile.make(.tv, order: order)

        VeyraBentoGrid(profile: profile) {
            if present.contains(.iptvFilms) {
                VeyraBentoShelf(title: "IPTV films", subtitle: "Nieuw toegevoegd") {
                    ForEach(model.iptvFilms) { film in
                        Button { onOpenIPTVFilm(film) } label: {
                            VeyraBentoPosterContent(title: film.name, url: film.posterURL, kind: .movie)
                        }
                        .buttonStyle(VeyraPosterFocusStyle())
                        .focused($focus, equals: .shelf("film-\(film.id)"))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .bentoCell(profile.cell(.iptvFilms))
            }

            if present.contains(.iptvSeries) {
                VeyraBentoShelf(title: "IPTV series", subtitle: "Nieuw toegevoegd") {
                    ForEach(model.iptvSeries) { series in
                        Button { onOpenIPTVSeries(series) } label: {
                            VeyraBentoPosterContent(title: series.name, url: series.coverURL, kind: .episode)
                        }
                        .buttonStyle(VeyraPosterFocusStyle())
                        .focused($focus, equals: .shelf("serie-\(series.id)"))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .bentoCell(profile.cell(.iptvSeries))
            }
        }
    }

    // MARK: Raster — onder: Filmcollecties (na Sport)

    @ViewBuilder
    private func bentoBottom(now: Date) -> some View {
        if layout.isVisible(.collecties), !model.collections.isEmpty {
            let profile = BentoProfile.make(.tv, order: [.collecties])

            VeyraBentoGrid(profile: profile) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filmcollecties")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))
                        .padding(.horizontal, 12)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(model.collections) { collection in
                                Button { onOpenCatalog(collection) } label: {
                                    VeyraBentoCollectionMiniContent(title: collection.name, url: collection.imageURL, showName: showCollectionNames)
                                }
                                .buttonStyle(VeyraBannerFocusStyle())
                                .focused($focus, equals: .shelf("col-\(collection.id)"))
                                .frame(width: 550, height: 248 + (showCollectionNames ? 34 : 0))
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                    }
                    .scrollClipDisabled()
                }
                // Even veel ruimte boven en onder de rij, zodat ze gecentreerd tussen de kaders staat.
                .frame(maxHeight: .infinity, alignment: .center)
                .bentoCell(profile.cell(.collecties))
            }
        }
    }

    private func reloadLayout() {
        let fresh = VeyraHomeLayoutStore.load()
        if fresh != layout { layout = fresh }
    }

    /// Knop + focus voor één tegel. `.bentoCell(...)` komt bij de aanroep, als laatste modifier.
    private func cell<Content: View>(_ tile: BentoTile, _ profile: BentoProfile,
                                     action: @escaping () -> Void,
                                     @ViewBuilder label: () -> Content) -> some View {
        Button(action: action) { label() }
            .buttonStyle(VeyraTileStyle())
            .focused($focus, equals: .bento(tile))
    }

    private func continueButton<Content: View>(_ item: ContinueItem, radius: CGFloat = 30,
                                               @ViewBuilder label: () -> Content) -> some View {
        Button { onPlay(item) } label: { label() }
            .buttonStyle(VeyraCaptionedTileStyle())
            .focused($focus, equals: .cont(item.id))
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

// MARK: - Ingeklapte hero (kopregel boven het raster)

private struct BentoCollapsedHero: View {
    let content: HeroContent

    // Clearlogo i.p.v. platte titeltekst -- zelfde patroon als de grote
    // hero (VeyraHeroView.logo): logo wanneer beschikbaar, anders de titel
    // als tekst zodat een titel zonder logo er ongewijzigd uitziet.
    @ViewBuilder
    private var collapsedLogo: some View {
        if let url = content.logoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                        .frame(maxWidth: 520, maxHeight: 110)
                        .frame(maxWidth: .infinity, alignment: .leading)
                default:
                    collapsedTitleText
                }
            }
        } else {
            collapsedTitleText
        }
    }

    private var collapsedTitleText: some View {
        Text(content.fallbackTitle)
            .font(.system(size: 56, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    var body: some View {
        let now = content.moments.first
        let next = content.moments.dropFirst().first

        ZStack(alignment: .bottomLeading) {
            VeyraArt(url: now?.backdropURL, seed: content.fallbackTitle)
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.1), VeyraHomeStyle.ink],
                           startPoint: .top, endPoint: .bottom)

            HStack(alignment: .bottom, spacing: 40) {
                VStack(alignment: .leading, spacing: 8) {
                    if let now {
                        HStack(spacing: 12) {
                            if now.isLive {
                                Circle().fill(VeyraHomeStyle.live).frame(width: 12, height: 12)
                                    .shadow(color: VeyraHomeStyle.live, radius: 5)
                            }
                            Text(now.label)
                                .font(.system(size: 22, weight: .bold))
                                .tracking(3)
                                .foregroundStyle(now.isLive ? VeyraHomeStyle.live : VeyraHomeStyle.cyan)
                            Text(now.title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(VeyraHomeStyle.dim)
                                .lineLimit(1)
                        }
                    }
                    collapsedLogo
                    if let now {
                        Text(now.metaLine)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                }
                Spacer(minLength: 0)
                if let next {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(next.label)
                            .font(.system(size: 20, weight: .bold))
                            .tracking(2.6)
                            .foregroundStyle(VeyraHomeStyle.cyan)
                        Text(next.title).font(.title3.weight(.semibold)).lineLimit(1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .frame(maxWidth: 420, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                }
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 24)
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Bento") {
    VeyraBentoHomeView(model: VeyraBentoViewModel.preview(),
                       sportModel: VeyraSportViewModel(provider: MockSportProvider()),
                       onPlay: { _ in })
}
#endif

#endif
