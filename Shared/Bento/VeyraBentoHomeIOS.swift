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

    @AppStorage(GeneralSettingsDefaults.showContinueWatchingKey) private var showContinueWatching = true
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 32) {
                    if let message = model.home.notice {
                        VeyraStatusMessage(text: message) { Task { await model.load(force: true) } }
                    }

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
                        bento(now: context.date)
                    }

                    if layout.showShelves { VeyraBentoUserShelves(compact: true, onOpen: onOpenTMDBTitle) }
                }
                .padding(.horizontal, 16)
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
        .onReceive(NotificationCenter.default.publisher(for: .veyraHomeLayoutDidChange)) { _ in reloadLayout() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in reloadLayout() }
        // Anders blijven "IPTV films"/"IPTV series" de oude, al-in-memory
        // lijst tonen totdat je handmatig ververst (pull-to-refresh) of de
        // app herstart, ook als je net iets verborgen hebt bij "VOD beheren".
        .onReceive(NotificationCenter.default.publisher(for: .iptvConfigurationDidChange)) { _ in
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
    private func bento(now: Date) -> some View {
        let live = model.liveRows(at: now)
        let today = showUpcoming ? model.today(at: now, limit: regular ? 4 : 3) : nil
        let items = showContinueWatching ? model.home.continueItems : []
        let present = presentTiles(items: items, live: live, hasToday: today != nil)
        let profile = BentoProfile.make(regular ? .tablet : .phone, order: layout.orderedTiles.filter { present.contains($0) })
        let rest = present.contains(.verder) ? Array(items.dropFirst()) : items

        VeyraBentoGrid(profile: profile) {
            if present.contains(.verder), let first = items.first {
                continueButton(first) { VeyraBentoContinueHeroContent(item: first, compact: true) }
                    .bentoCell(profile.cell(.verder))
            }

            if present.contains(.volgende) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(rest) { item in
                                continueButton(item, radius: 16) { VeyraBentoContinueMiniContent(item: item, compact: true) }
                                    .frame(width: regular ? 340 : 270, height: regular ? 116 : 92)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .bentoCell(profile.cell(.volgende))
            }

            if present.contains(.releasesFilms) {
                VeyraBentoShelf(title: "Nieuwe films", subtitle: "Nieuw uitgebracht", compact: true, contentHeight: (regular ? 240 : 190) + 36) {
                    ForEach(model.releaseFilms) { title in
                        Button { onOpenTMDBTitle(title) } label: {
                            VeyraBentoPosterContent(title: title.title, url: title.posterURL, compact: true, posterHeight: regular ? 240 : 190, watchedID: title.id, watchedKind: title.kind)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .veyraHomeTileMenu(.releasesFilms)
                .bentoCell(profile.cell(.releasesFilms))
            }

            if present.contains(.releasesSeries) {
                VeyraBentoShelf(title: "Nieuwe series", subtitle: "Nieuw uitgebracht", compact: true, contentHeight: (regular ? 240 : 190) + 36) {
                    ForEach(model.releaseSeries) { title in
                        Button { onOpenTMDBTitle(title) } label: {
                            VeyraBentoPosterContent(title: title.title, url: title.posterURL, compact: true, posterHeight: regular ? 240 : 190, watchedID: title.id, watchedKind: title.kind)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .veyraHomeTileMenu(.releasesSeries)
                .bentoCell(profile.cell(.releasesSeries))
            }

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
                            .frame(width: regular ? 190 : 150, height: regular ? 76 : 60)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .veyraHomeTileMenu(.streaming)
                .bentoCell(profile.cell(.streaming))
            }

            if present.contains(.collecties) {
                VeyraBentoShelf(title: "Filmcollecties", subtitle: "Complete filmreeksen", compact: true, contentHeight: 134) {
                    ForEach(model.collections) { collection in
                        Button { onOpenCatalog(collection) } label: {
                            VeyraBentoLandscapeContent(title: collection.name, url: collection.imageURL, compact: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .veyraHomeTileMenu(.collecties)
                .bentoCell(profile.cell(.collecties))
            }

            if present.contains(.vandaag), let today {
                cell(action: { if let first = today.items.first { toggle(first) } }) {
                    VeyraBentoTodayContent(today: today, now: now, reminders: model.home.reminderIDs, compact: true)
                }
                .contextMenu {
                    ForEach(today.items) { item in
                        let on = model.home.reminderIDs.contains(item.id)
                        Button { toggle(item) } label: {
                            Label(on ? "Herinnering uit · \(item.title)" : "Herinner mij · \(item.title)",
                                  systemImage: on ? "bell.slash" : "bell")
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: model.home.reminderIDs)
                .bentoCell(profile.cell(.vandaag))
            }
        }
    }

    /// Welke blokken nu getoond worden: door de gebruiker aangezet én er is iets om te tonen.
    private func presentTiles(items: [ContinueItem], live: [BentoLiveRow], hasToday: Bool) -> Set<BentoTile> {
        var present = Set<BentoTile>()
        func add(_ tile: BentoTile, _ hasContent: Bool) {
            if layout.isVisible(tile), hasContent { present.insert(tile) }
        }
        add(.verder, !items.isEmpty)
        add(.volgende, items.count > (layout.isVisible(.verder) ? 1 : 0))
        add(.releasesFilms, !model.releaseFilms.isEmpty)
        add(.releasesSeries, !model.releaseSeries.isEmpty)
        add(.live, !live.isEmpty)
        add(.vandaag, hasToday)
        add(.iptvFilms, !model.iptvFilms.isEmpty)
        add(.iptvSeries, !model.iptvSeries.isEmpty)
        add(.streaming, !model.providers.isEmpty)
        add(.collecties, !model.collections.isEmpty)
        return present
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
        Button { onPlay(item) } label: { label() }
            .buttonStyle(VeyraPressStyle(cornerRadius: radius))
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
