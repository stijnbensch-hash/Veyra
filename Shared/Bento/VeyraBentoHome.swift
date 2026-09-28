// VeyraBentoHome.swift — tvOS 17+
// De bento-home: rijen voor Verder kijken, Binnenkort, Live TV, films en series,
// met daaronder optioneel de sectie Sport.
//
// Bediening:
//   select Verder kijken   -> afspelen (lang indrukken: verwijderen uit Verder kijken)
//   select Live nu         -> onOpenLiveTV(zenderID)
//   select Vandaag         -> herinnering aan/uit (lang indrukken: per titel)
//   select Tijd voor jou   -> eerste suggestie afspelen (lang indrukken: alle suggesties)
//   select Nieuw / Bronnen -> onOpenNew() / onOpenSources()
//
// Vereist: VeyraBentoLayout/Model/Tiles.swift, VeyraBentoFocus.swift (VeyraHomeFocus, VeyraTileStyle),
//          VeyraBentoStyle.swift, VeyraBentoTrakt.swift, VeyraBentoEPGModel.swift,
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
    var onOpenIPTVFilm: (IPTVHomeFilm) -> Void
    var onOpenIPTVSeries: (IPTVHomeSeries) -> Void
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
    @AppStorage(GeneralSettingsDefaults.liveFavoritesOnlyKey) private var liveFavoritesOnly = false
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
         onOpenIPTVFilm: @escaping (IPTVHomeFilm) -> Void = { _ in },
         onOpenIPTVSeries: @escaping (IPTVHomeSeries) -> Void = { _ in },
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

    // MARK: Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 48) {
                // "Context Ribbon": tvOS heeft geen grote hero bovenaan Home, dus dit is
                // hier meteen het eerste wat je ziet -- precies de plek die de brainstorm
                // bedoelde ("de home voelt direct anders zonder de hele layout te wijzigen").
                TimelineView(.periodic(from: .now, by: 5)) { context in
                    VeyraContextRibbon(items: contextRibbonItems(now: context.date))
                }

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

    // MARK: Veyra Now (Context Ribbon)
    // Elke kandidaat krijgt een relevantiescore mee -- de ribbon zelf sorteert
    // erop, dus wat nú het meest telt (wedstrijd bijna afgelopen > zender die
    // net begint > gewoon verder kijken > iets dat pas later komt) staat vooraan.

    private func contextRibbonItems(now: Date) -> [VeyraRibbonItem] {
        var items: [VeyraRibbonItem] = []

        if showContinueWatching, let item = model.home.continueItems.first {
            items.append(VeyraRibbonItem(
                id: "ribbon-continue-\(item.id)", icon: "play.fill", label: "VERDER KIJKEN",
                text: item.title, detail: item.subtitle ?? item.baseMetaText, priority: 50,
                action: { onPlay(item) }))
        }

        if showUpcoming, let item = model.today(at: now, limit: 1)?.items.first {
            let minutesUntilAiring = item.airDate.timeIntervalSince(now) / 60
            let airingSoon = !item.isDateOnly && minutesUntilAiring > 0 && minutesUntilAiring <= 180
            let startText = item.isDateOnly
                ? item.airDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(VeyraHomeFormat.locale))
                : item.airDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute().locale(VeyraHomeFormat.locale))
            let detail = [item.subtitle, startText].compactMap { $0 }.joined(separator: " · ")
            items.append(VeyraRibbonItem(
                id: "ribbon-upcoming-\(item.id)", icon: "calendar",
                label: item.kind == .movie ? "FILM BINNENKORT" : "VOLGENDE AFLEVERING",
                text: item.title, detail: detail, priority: airingSoon ? 75 : 40,
                action: { onToggleReminder(item, !model.home.reminderIDs.contains(item.id)) }))
        }

        if let row = model.liveRows(at: now, limit: 1, favoritesOnly: liveFavoritesOnly).first {
            let justStarted = row.progress < 0.1
            items.append(VeyraRibbonItem(
                id: "ribbon-live-\(row.id)", icon: "dot.radiowaves.left.and.right", label: "LIVE NU",
                text: row.title, detail: "\(row.channelName) · nog \(row.remainingMinutes) min", isLive: true,
                priority: justStarted ? 85 : (row.isSports ? 65 : 55),
                action: { onPlayChannel(row.channelID) }))
        }

        if layout.showSport, let sportModel, let event = sportModel.featured(at: now) {
            let live = event.isLive(at: now)
            let remaining = event.remainingMinutes(at: now) ?? .max
            let nearEnd = live && remaining <= 20
            items.append(VeyraRibbonItem(
                id: "ribbon-sport-\(event.id)", icon: "sportscourt", label: live ? "SPORT · LIVE" : "SPORT · STRAKS",
                text: event.title,
                detail: live ? "Live op \(event.channelName)" : "Start \(event.start.formatted(.dateTime.hour().minute().locale(VeyraHomeFormat.locale))) · \(event.channelName)",
                isLive: live,
                priority: nearEnd ? 100 : (live ? 90 : 60),
                action: { onPlaySport(event, .live) }))
        }

        return items
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
        // "Universal Timeline": vervangt de twee losse rijen hieronder door één chronologisch
        // gesorteerde rij, zolang de gebruiker dit blok expliciet aanzette (zie VeyraHomeLayout).
        let showTimeline = layout.isVisible(.tijdlijn) && (!items.isEmpty || !(today?.items.isEmpty ?? true))
        let showVolgende = !showTimeline && layout.isVisible(.volgende) && !items.isEmpty
        let showVandaag = !showTimeline && layout.isVisible(.vandaag) && today != nil

        if showTimeline {
            let profile = BentoProfile.make(.tv, order: [.tijdlijn])
            let entries = veyraTimelineEntries(continueItems: items, upcoming: today?.items ?? [])

            VeyraBentoGrid(profile: profile) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tijdlijn")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))
                        .padding(.horizontal, 12)

                    // Twee rijen naast elkaar i.p.v. één lange rij -- meer items in beeld,
                    // en dichter bij hoe "Verder kijken" + "Binnenkort" er vroeger uitzagen.
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: [
                            GridItem(.fixed(VeyraCaptionedCardLayout.tv.height + 28), spacing: 24),
                            GridItem(.fixed(VeyraCaptionedCardLayout.tv.height + 28), spacing: 24)
                        ], alignment: .top, spacing: 24) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                // Vast label-hoogte reserveren i.p.v. `height: 1` -- anders verschilt de
                                // totale kaarthoogte per item en centreert LazyHGrid de kaarten niet meer
                                // op dezelfde lijn (kaart "zakt" bij een item zonder eigen NU/tijd-label).
                                VStack(alignment: .leading, spacing: 8) {
                                    Group {
                                        if index == 0 || entry.bucketLabel(now: now) != entries[index - 1].bucketLabel(now: now) {
                                            Text(entry.bucketLabel(now: now))
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .tracking(1)
                                                .foregroundStyle(entry.isNow ? VeyraColors.red : VeyraHomeStyle.dim)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                    .frame(height: 20, alignment: .leading)
                                    timelineCard(entry, now: now, featuredContinueID: items.first?.id)
                                        .frame(width: VeyraCaptionedCardLayout.tv.width,
                                               height: VeyraCaptionedCardLayout.tv.height)
                                }
                                .frame(height: VeyraCaptionedCardLayout.tv.height + 28, alignment: .top)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                    }
                    .scrollClipDisabled()
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .bentoCell(profile.cell(.tijdlijn))
            }
        } else if showVolgende || showVandaag {
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
                            LazyHStack(spacing: 24) {
                                ForEach(items) { item in
                                    continueButton(item, radius: 22) {
                                        // "Slimme Bento": de meest relevante kaart (bovenaan de
                                        // rij, dus meest recent) krijgt een gloed/badge -- geen
                                        // enkele maat verandert, dus de rij/cel blijft exact even
                                        // hoog als voorheen.
                                        VeyraBentoContinueMiniContent(item: item, isFeatured: item.id == items.first?.id)
                                    }
                                        // Beide rijen gebruiken dezelfde vaste tvOS-maat; binnenin
                                        // hebben beeld en onderschrift elk hun eigen hoogte, ongeacht
                                        // of de titel tekst of een clearlogo is.
                                        .frame(width: VeyraCaptionedCardLayout.tv.width,
                                               height: VeyraCaptionedCardLayout.tv.height)
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
                            LazyHStack(spacing: 24) {
                                ForEach(today.items) { item in
                                    let on = model.home.reminderIDs.contains(item.id)
                                    Button { toggle(item) } label: {
                                        VeyraBentoUpcomingCardContent(item: item, now: now, isReminded: on)
                                    }
                                    .buttonStyle(VeyraCaptionedTileStyle())
                                    .focused($focus, equals: .cont("upcoming-\(item.id)"))
                                    // Zelfde formaat en onderverdeling als "Verder kijken".
                                    .frame(width: VeyraCaptionedCardLayout.tv.width,
                                           height: VeyraCaptionedCardLayout.tv.height)
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
        let live = model.liveRows(at: now, limit: 8, recentFirst: true, favoritesOnly: liveFavoritesOnly)
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
                    LazyHStack(spacing: 24) {
                        ForEach(model.providers) { provider in
                            Button { onOpenCatalog(provider) } label: {
                                VeyraBentoStreamingContent(name: provider.name, iconURL: provider.imageURL,
                                                           wideURL: provider.wideURL, brand: provider.brand,
                                                           customURL: provider.customLogoURL)
                            }
                            .buttonStyle(VeyraStreamingTileStyle())
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
                            VeyraBentoPosterContent(title: film.name, url: film.posterURL,
                                                    kind: .movie, sourceLabel: film.providerName)
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
                            VeyraBentoPosterContent(title: series.name, url: series.coverURL,
                                                    kind: .episode, sourceLabel: series.providerName)
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
                        LazyHStack(spacing: 24) {
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

    /// Kaart voor één item van de Universal Timeline -- hergebruikt dezelfde knop/focus/contextmenu-
    /// logica als de losse "Verder kijken"/"Binnenkort"-rijen (`continueButton`/`toggle` hierboven),
    /// enkel via de gemeenschappelijke `VeyraTimelineEntry`.
    @ViewBuilder
    private func timelineCard(_ entry: VeyraTimelineEntry, now: Date, featuredContinueID: String?) -> some View {
        switch entry {
        case .now(let item):
            continueButton(item, radius: 22) {
                VeyraBentoContinueMiniContent(item: item, isFeatured: item.id == featuredContinueID)
            }
        case .later(let item):
            let on = model.home.reminderIDs.contains(item.id)
            Button { toggle(item) } label: {
                VeyraBentoUpcomingCardContent(item: item, now: now, isReminded: on)
            }
            .buttonStyle(VeyraCaptionedTileStyle())
            .focused($focus, equals: .cont("upcoming-\(item.id)"))
            .contextMenu {
                Button { toggle(item) } label: {
                    Label(on ? "Herinnering uit · \(item.title)" : "Herinner mij · \(item.title)",
                          systemImage: on ? "bell.slash" : "bell")
                }
            }
        }
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

// MARK: - Preview

#if DEBUG
#Preview("Bento") {
    VeyraBentoHomeView(model: VeyraBentoViewModel.preview(),
                       sportModel: VeyraSportViewModel(provider: MockSportProvider()),
                       onPlay: { _ in })
}
#endif

#endif
