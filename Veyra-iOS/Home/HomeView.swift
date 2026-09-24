import SwiftUI

struct HomeView: View {
    @State private var bentoTitle: ContinueItem?
    @State private var bentoChannel: PlayableSource?
    @State private var bentoFilm: IPTVVODItem?
    @State private var bentoSeries: XtreamSeriesItem?
    @State private var bentoRelease: BentoTMDBTitle?
    @State private var bentoCatalog: BentoCatalog?

    var body: some View {
        NavigationStack {
            homeContent
                .toolbar(.hidden, for: .navigationBar)
                .modifier(HomeDestinations(
                    title: $bentoTitle, channel: $bentoChannel, film: $bentoFilm,
                    series: $bentoSeries, release: $bentoRelease, catalog: $bentoCatalog))
                .modifier(HomeActiveTracking(
                    title: bentoTitle, channel: bentoChannel, film: bentoFilm,
                    series: bentoSeries, release: bentoRelease, catalog: bentoCatalog))
        }
    }

    private var homeContent: some View {
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
            onPlaySport: { _, _ in openTab(.live) },
            onOpenCompetition: { _ in openTab(.sports) }
        )
    }

    private func openTab(_ tab: HomeRequestedTab) {
        HomeNavigationState.shared.requestedTab = tab
    }

    private func playChannel(_ id: String) {
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
    @Binding var film: IPTVVODItem?
    @Binding var series: XtreamSeriesItem?
    @Binding var release: BentoTMDBTitle?
    @Binding var catalog: BentoCatalog?

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $title) { item in
                VeyraBentoTitleDestination(item: item)
            }
            .navigationDestination(item: $channel) { source in
                PlayerView(source: source, item: MediaItem(title: source.name, type: .liveTV))
            }
            .navigationDestination(item: $film) { film in
                PlayerView(source: film.playableSource)
            }
            .navigationDestination(item: $series) { series in
                IPTVSeriesEpisodesView(series: series)
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
    let film: IPTVVODItem?
    let series: XtreamSeriesItem?
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
