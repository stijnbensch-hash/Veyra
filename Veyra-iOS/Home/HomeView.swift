import SwiftUI

struct HomeView: View {
    /// Zoek-/instellingenknoppen horen enkel op dit hoofdscherm: ze zitten als overlay op de
    /// root van de NavigationStack, dus elk gepusht subscherm ligt er vanzelf overheen.
    var floatingButtons = false
    var showsSettings = true
    var onSearch: () -> Void = {}
    var onSettings: () -> Void = {}

    @State private var bentoTitle: ContinueItem?
    @State private var bentoChannel: PlayableSource?
    @State private var bentoFilm: IPTVHomeFilm?
    @State private var bentoSeries: IPTVHomeSeries?
    @State private var bentoRelease: BentoTMDBTitle?
    @State private var bentoCatalog: BentoCatalog?
    @State private var sportQuery: SportChannelQuery?
    @State private var activeSportEvent: SportEvent?

    var body: some View {
        NavigationStack {
            homeContent
                .veyraHideNavigationBar()
                .sportChannelSheet($sportQuery) { bentoChannel = $0 }
                .modifier(HomeDestinations(
                    title: $bentoTitle, channel: $bentoChannel, film: $bentoFilm,
                    series: $bentoSeries, release: $bentoRelease, catalog: $bentoCatalog,
                    sportEvent: activeSportEvent))
                .modifier(HomeActiveTracking(
                    title: bentoTitle, channel: bentoChannel, film: bentoFilm,
                    series: bentoSeries, release: bentoRelease, catalog: bentoCatalog))
                .mediaNavigationRoot()
        }
    }

    private var homeContent: some View {
        // De zoek-/instellingenknoppen worden nu ALS DEEL VAN de scrollende inhoud getekend (eerste
        // element bovenaan in VeyraBentoHomeIOS.swift), niet als losse vaste/zwevende balk erboven --
        // ze schuiven dus gewoon mee omhoog en verdwijnen bij het scrollen, i.p.v. altijd zichtbaar
        // te blijven staan (en dus ook geen apart achtergrond-/toolbar-gedoe meer nodig).
        VeyraBentoHomeView(
            model: VeyraBentoServices.shared.bento,
            sportModel: VeyraBentoServices.shared.sport,
            onPlay: { bentoTitle = $0 },
            onOpenLiveTV: { _ in openTab(.live) },
            onPlayChannel: playChannel,
            onOpenIPTVFilm: { bentoFilm = $0 },
            onOpenIPTVSeries: { bentoSeries = $0 },
            onOpenTMDBTitle: { bentoRelease = $0 },
            onOpenCatalog: { bentoCatalog = $0 },
            onPlaySport: { event, _ in sportQuery = SportChannelQuery(event: event); activeSportEvent = event },
            onOpenCompetition: { _ in openTab(.sports) },
            floatingButtons: floatingButtons,
            showsSettings: showsSettings,
            onSearch: onSearch,
            onSettings: onSettings
        )
    }

    private func openTab(_ tab: HomeRequestedTab) {
        HomeNavigationState.shared.requestedTab = tab
    }

    private func playChannel(_ id: String) {
        activeSportEvent = nil
        if let source = VeyraBentoServices.shared.playableSource(forChannelID: id) {
            bentoChannel = source
        } else {
            openTab(.live)
        }
    }
}

/// Alle pushbestemmingen van Home, apart gehouden zodat de compiler ze snel kan controleren.
private struct HomeDestinations: ViewModifier {
    @Binding var title: ContinueItem?
    @Binding var channel: PlayableSource?
    @Binding var film: IPTVHomeFilm?
    @Binding var series: IPTVHomeSeries?
    @Binding var release: BentoTMDBTitle?
    @Binding var catalog: BentoCatalog?
    var sportEvent: SportEvent? = nil

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $title) { item in
                VeyraBentoTitleDestination(item: item)
            }
            .navigationDestination(item: $channel) { source in
                // `sportEvent` geeft op iOS de live-matchoverlay (`VeyraMatchCenterOverlay`) door aan
                // `PlayerView`. Op macOS is dat een ander type (`MacPlayerView.swift`'s eigen
                // `PlayerView`, zonder die parameter) -- geen massale refactor hiervoor, gewoon
                // per platform de juiste initializer aanroepen.
                #if os(iOS)
                PlayerView(source: source, item: MediaItem(title: source.name, type: .liveTV), sportEvent: sportEvent)
                #else
                PlayerView(source: source, item: MediaItem(title: source.name, type: .liveTV))
                #endif
            }
            .navigationDestination(item: $film) { film in
                PlayerView(source: film.playableSource)
            }
            .navigationDestination(item: $series) { series in
                IPTVSeriesEpisodesView(series: series.item, providerID: series.providerID,
                                       providerName: series.providerName)
            }
            .navigationDestination(item: $catalog) { catalog in
                VeyraBentoCatalogView(catalog: catalog, onOpen: { release = $0 })
            }
            .navigationDestination(item: $release) { title in
                VeyraBentoTitleDestination(kind: title.kind, tmdbID: title.id)
            }
    }
}

/// Meldt aan de gedeelde Home-navigatiestatus of er een scherm geopend is (zwevende knoppen verdwijnen dan).
private struct HomeActiveTracking: ViewModifier {
    let title: ContinueItem?
    let channel: PlayableSource?
    let film: IPTVHomeFilm?
    let series: IPTVHomeSeries?
    let release: BentoTMDBTitle?
    let catalog: BentoCatalog?

    private var anyOpen: Bool {
        title != nil || channel != nil || film != nil || series != nil || release != nil || catalog != nil
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: anyOpen) { _, isOpen in
                HomeNavigationState.shared.setActive(isOpen, source: "bento")
            }
    }
}
