import SwiftUI

private enum TrendingHeroItem: Identifiable {
    case movie(TMDBMovie)
    case series(TMDBSeries)

    var id: String {
        switch self {
        case .movie(let movie): return "movie:\(movie.id)"
        case .series(let series): return "series:\(series.id)"
        }
    }

    var content: VeyraHeroContent {
        switch self {
        case .movie(let movie): return .movie(movie)
        case .series(let series): return .series(series)
        }
    }
}

struct ContentView: View {
    @State private var destination: MenuDestination?
    @State private var playerVisible = false
    @State private var navigationRootID = UUID()
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var heroSpotlight = VeyraHeroSpotlight.shared
    @State private var heroRotationIndex = 0
    @State private var heroPool: [TrendingHeroItem] = []

    @FocusState
    private var focusedItem: MenuDestination?

    @FocusState
    private var heroSwipeFocused: Bool

    private let contentMargin: CGFloat = VeyraSpacing.page

    private var trendingItem: TrendingHeroItem? {
        guard !heroPool.isEmpty else { return nil }
        let index = heroRotationIndex % heroPool.count
        return heroPool[index]
    }

    private var heroContent: VeyraHeroContent? {
        heroSpotlight.focused ?? trendingItem?.content
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 0) {

                    ScrollView(
                        .vertical,
                        showsIndicators: false
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: 48
                        ) {
                            if let heroContent {
                                ZStack(alignment: .top) {
                                    Group {
                                        if heroSpotlight.focused != nil {
                                            VeyraSpotlightHero(content: heroContent)
                                        } else if let trendingItem {
                                            switch trendingItem {
                                            case .movie(let movie): VeyraMovieHero(movie: movie)
                                            case .series(let series): VeyraSeriesHero(series: series)
                                            }
                                        }
                                    }
                                    .id(heroContent.id)
                                    .frame(minHeight: 410, alignment: .center)
                                    .animation(.easeInOut(duration: 0.35), value: heroContent.id)

                                    if heroSpotlight.focused == nil, heroPool.count > 1 {
                                        Color.clear
                                            .frame(height: 300)
                                            .contentShape(Rectangle())
                                            .focusable(true)
                                            .focused($heroSwipeFocused)
                                            .focusEffectDisabled()
                                            .onMoveCommand { direction in
                                                switch direction {
                                                case .left:
                                                    heroRotationIndex =
                                                        (heroRotationIndex - 1 + heroPool.count)
                                                        % heroPool.count
                                                case .right:
                                                    heroRotationIndex =
                                                        (heroRotationIndex + 1) % heroPool.count
                                                default: break
                                                }
                                            }
                                            .accessibilityLabel("Uitgelicht wisselen")
                                            .accessibilityHint(
                                                "Links of rechts vegen om een andere titel te tonen."
                                            )
                                    }
                                }
                            }

                            TraktContinueWatchingView()

                            TraktUpcomingView()

                            VeyraRecentLiveTVHomeView()
                            SportsHomeView()

                            IPTVRecentlyAddedSeriesRow()
                            IPTVRecentlyAddedVODRow()
                            JellyfinRecentlyAddedRow()

                            ShelvesHomeSection()

                            if !viewModel.featuredMovies.isEmpty {
                                VStack(alignment: .leading, spacing: 20) {
                                    VeyraSectionHeader(
                                        title: "Populaire films",
                                        subtitle: "Voor jou geselecteerd"
                                    )
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: VeyraSpacing.rail) {
                                            ForEach(viewModel.featuredMovies) { movie in
                                                NavigationLink { VeyraMovieDestination(movie: movie, play: false) } label: {
                                                    VeyraPosterCard(title: movie.title, url: movie.posterPath.flatMap {
                                                        URL(string: "https://image.tmdb.org/t/p/w500" + $0)
                                                    }, width: 250,
                                                    genre: TMDBGenreNames.firstMovieName(for: movie.genreIDs ?? []),
                                                    rating: movie.voteAverage)
                                                    .traktWatched(.movie(TraktIDs(tmdb: movie.id)))
                                                }.buttonStyle(VeyraFocusButtonStyle(radius: VeyraRadius.poster))
                                                    .reportsHero(.movie(movie))
                                            }
                                        }.padding(12)
                                    }.scrollClipDisabled()
                                }
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .padding(
                            .horizontal,
                            contentMargin
                        )
                        .padding(
                            .top,
                            36
                        )
                        .padding(
                            .bottom,
                            50
                        )
                    }
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
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
        .task {
            async let moviesLoad: Void = viewModel.loadFeaturedMoviesIfNeeded()
            async let seriesLoad: Void = viewModel.loadFeaturedSeriesIfNeeded()
            _ = await (moviesLoad, seriesLoad)

            guard heroPool.isEmpty else { return }

            var items: [TrendingHeroItem] =
                viewModel.featuredMovies.map { .movie($0) }
                + viewModel.featuredSeries.map { .series($0) }
            items.shuffle()
            heroPool = items
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(16))

                guard heroSpotlight.focused == nil, heroPool.count > 1 else {
                    continue
                }

                heroRotationIndex += 1
            }
        }
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

    // MARK: - Background

    private var background: some View {
        VeyraArtworkBackground(url: heroContent?.backdropURL)
    }
}

#Preview { ContentView() }
