import SwiftUI

struct ContentView: View {
    @State private var destination: MenuDestination?
    @State private var playerVisible = false
    @State private var navigationRootID = UUID()
    @State private var bentoTitle: ContinueItem?
    @State private var bentoChannel: PlayableSource?
    @State private var bentoFilm: IPTVVODItem?
    @State private var bentoSeries: XtreamSeriesItem?
    @State private var bentoRelease: BentoTMDBTitle?
    @State private var bentoCatalog: BentoCatalog?
    @State private var sportQuery: SportChannelQuery?

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraHomeStyle.ink.ignoresSafeArea()

                VStack(spacing: 0) {
                    VeyraBentoHomeView(
                        model: VeyraBentoServices.shared.bento,
                        sportModel: VeyraBentoServices.shared.sport,
                        onPlay: { bentoTitle = $0 },
                        onOpenLiveTV: { _ in destination = .liveTV },
                        onPlayChannel: { id in
                            if let source = VeyraBentoServices.shared.playableSource(forChannelID: id) {
                                bentoChannel = source
                            } else {
                                destination = .liveTV
                            }
                        },
                        onOpenIPTVFilm: { bentoFilm = $0 },
                        onOpenIPTVSeries: { bentoSeries = $0 },
                        onOpenTMDBTitle: { bentoRelease = $0 },
                        onOpenCatalog: { bentoCatalog = $0 },
                        onPlaySport: { event, _ in sportQuery = SportChannelQuery(event: event) },
                        onOpenCompetition: { _ in destination = .sport }
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
            }

            // Alleen de grote horizontale tvOS-safe-area verwijderen.
            // Boven en onder blijven intact voor goede focusnavigatie.
            .ignoresSafeArea(
                .container,
                edges: .horizontal
            )
            .navigationDestination(item: $bentoTitle) { item in
                VeyraBentoTitleDestination(item: item)
            }
            .sportChannelSheet($sportQuery) { bentoChannel = $0 }
            .navigationDestination(item: $bentoChannel) { source in
                PlayerView(source: source, item: MediaItem(title: source.name, type: .liveTV))
            }
            .navigationDestination(item: $bentoFilm) { film in
                PlayerView(source: film.playableSource)
            }
            .navigationDestination(item: $bentoSeries) { series in
                IPTVSeriesDetailView(series: series)
            }
            .navigationDestination(item: $bentoCatalog) { catalog in
                VeyraBentoCatalogView(catalog: catalog, onOpen: { bentoRelease = $0 })
            }
            .navigationDestination(item: $bentoRelease) { title in
                VeyraBentoTitleDestination(kind: title.kind, tmdbID: title.id)
            }
            .navigationDestination(
                item: $destination
            ) { destination in
                switch destination {
                case .home:
                    EmptyView()
                case .account:
                    AccountView()
                case .film:
                    MoviesView()

                case .series:
                    SeriesView()

                case .liveTV:
                    LiveTVView()

                case .sport:
                    SportsView()

                case .search:
                    SearchView()

                case .settings:
                    SettingsView()
                }
            }
        }
        .id(navigationRootID)
        .environment(\.veyraPlayerVisibility, { playerVisible = $0 })
        .safeAreaInset(edge: .top, spacing: 0) {
            if !playerVisible {
                VeyraTopNavigation(selected: destination ?? .home) { route in
                    destination = route == .home ? nil : route
                    if route == .home { navigationRootID = UUID() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(VeyraColors.cyan)
    }
}

#Preview { ContentView() }
