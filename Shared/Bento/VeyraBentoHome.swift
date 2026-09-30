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

    @AppStorage(GeneralSettingsDefaults.showContinueWatchingKey) private var showContinueWatching = true
    @AppStorage(TMDBCatalogLanguageFilter.key) private var catalogLanguages = "nl-en"
    @AppStorage(GeneralSettingsDefaults.showUpcomingKey) private var showUpcoming = true
    @AppStorage(GeneralSettingsDefaults.liveFavoritesOnlyKey) private var liveFavoritesOnly = false
    @State private var layout = VeyraHomeLayoutStore.load()
    @State private var nowSettings = VeyraNowSettingsStore.load()
    @State private var trendingItems: [HeroSpotlightItem] = []
    @State private var voorJouItems: [HeroSpotlightItem] = []
    @State private var top10Items: [HeroSpotlightItem] = []
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
                    VeyraContextRibbon(items: contextRibbonItems(now: context.date), now: context.date)
                }

                if let message = model.home.notice {
                    VeyraStatusMessage(text: message) { Task { await model.load(force: true) } }
                }

                // "Verder kijken" en "Binnenkort" helemaal bovenaan, los van de rest van het raster.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    bentoTop(now: context.date)
                }

                // "Discovery Flow": Trending, los van het bento-raster -- Stap 9 van het
                // Home Visual System-spec, direct na "Verder kijken" (spec §97).
                VeyraDiscoveryFlow(title: "Trending", items: trendingItems)

                // "Dynamic Mosaic": Voor Jou -- Stap 10, direct na Trending (spec §97).
                VeyraMosaicSection(title: "Voor jou", items: voorJouItems)

                TimelineView(.periodic(from: .now, by: 30)) { context in
                    bentoMiddle(now: context.date)
                }

                // "Binnenkort" teruggezet in "Verder kijken"-rij (zie bentoTop) -- geen
                // losse Calendar Horizon-sectie meer.

                // "Live nu" teruggezet als vaste rasterrij (samen met Streaming), i.p.v.
                // de losse On Air-sectie van Stap 13 -- op uitdrukkelijk verzoek teruggedraaid.
                // "Sports Stage": uitgelichte live wedstrijd, los van de rest van de
                // Sport-sectie -- Stap 14, direct na Nu op tv, vóór Live Sport (spec §97).
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    bentoSportsStage(now: context.date)
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

                // "Top 10 Orbit": laatste sectie op Home -- Stap 15, direct na
                // Live Sport (spec §97).
                VeyraTop10Orbit(title: "Top 10", items: top10Items)

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
        .background(VeyraBackground())
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .task { await model.load() }
        // Trending/Voor jou/Top 10 NA ELKAAR laden (niet gelijktijdig): elke
        // HeroSpotlightLoader-call doet zelf al tot 14 gelijktijdige TMDB-
        // clearlogo-verzoeken. Alle drie tegelijk bovenop de IPTV-opstart-
        // ververs (zware VOD-JSON-decode, zie VeyraApp.swift) en model.load()
        // duwde het geheugengebruik op tvOS te hoog -- app-crash bij opstart.
        // Na elkaar geeft hetzelfde eindresultaat, met veel lagere piekbelasting.
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
                    logoURL: event.homeLogoURL, secondaryLogoURL: event.awayLogoURL,
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
            let releases = (model.releaseFilms.map { ($0, "Film") } + model.releaseSeries.map { ($0, "Serie") })
                .sorted { ($0.0.releaseDate ?? .distantPast) > ($1.0.releaseDate ?? .distantPast) }
            // Niet altijd dezelfde titel: roteert dagelijks door de meest recente, nog niet
            // weggetikte releases (i.p.v. permanent de allerlaatste te tonen), zodat dit blok
            // ook bij herladen/scrollen dezelfde dag stabiel blijft maar van dag tot dag wisselt.
            let pool = Array(releases.filter { !nowSettings.isHidden("ribbon-release-\($0.0.id)", now: now) }.prefix(10))
            if !pool.isEmpty {
                let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0
                let (title, kindLabel) = pool[dayOfYear % pool.count]
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
        // "Binnenkort" teruggezet als vaste rasterrij naast "Verder kijken" (op
        // uitdrukkelijk verzoek teruggedraaid uit de losse Calendar Horizon-sectie
        // van Stap 12 -- weer gewoon één rij, zoals voorheen).
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
                        Text("Verder kijken (\(items.count))")
                            .font(.system(size: 20, weight: .bold))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))
                            .padding(.horizontal, 12)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 24) {
                                // "Resume Flow": het meest relevante item (bovenaan de rij, dus
                                // meest recent) krijgt een brede, filmische kaart met backdrop,
                                // clearlogo en voortgangslijn i.p.v. dezelfde kleine kaart als de
                                // rest -- zelfde rijhoogte, dus de rest van het raster verandert niet.
                                if let hero = items.first {
                                    Button { onPlay(hero) } label: {
                                        VeyraBentoContinueHeroContent(item: hero, showLabel: false)
                                            .clipShape(VeyraRadius.posterShape)
                                            .overlay(VeyraRadius.posterShape.strokeBorder(VeyraFrame.active, lineWidth: 2))
                                            .shadow(color: VeyraColors.cyan.opacity(0.28), radius: 20, x: -4, y: 4)
                                    }
                                    .buttonStyle(VeyraCaptionedTileStyle())
                                    .focused($focus, equals: .cont(hero.id))
                                    .contextMenu {
                                        if hero.playbackID != nil {
                                            Button(role: .destructive) { Task { await model.home.remove(hero) } } label: {
                                                Label("Verwijder uit Verder kijken", systemImage: "xmark.circle")
                                            }
                                        }
                                    }
                                    .frame(width: VeyraCaptionedCardLayout.tv.width * 1.6,
                                           height: VeyraCaptionedCardLayout.tv.height)
                                }
                                ForEach(items.dropFirst()) { item in
                                    continueButton(item, radius: 22) {
                                        VeyraBentoContinueMiniContent(item: item)
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

    // MARK: Sports Stage (Live Sport)

    @ViewBuilder
    private func bentoSportsStage(now: Date) -> some View {
        if layout.showSport, let sportModel, let featured = sportModel.liveEvents(at: now).first {
            VeyraSportsStage(event: featured, now: now) {
                onPlaySport(featured, .live)
            }
        }
    }

    // MARK: Raster — Streamingdiensten

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
                                VeyraLogoShelfTile(name: provider.name, iconURL: provider.imageURL,
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
