import SwiftUI
import Foundation

struct IPTVRecentlyAddedSeriesRow: View {
    @State private var seriesItems: [XtreamSeriesItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAllSeries = false
    @State private var isRefreshing = false

    private let posterWidth: CGFloat = 220

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            headerView

            if isLoading {
                loadingView

            } else if let errorMessage {
                errorView(
                    errorMessage
                )

            } else if seriesItems.isEmpty {
                emptyView

            } else {
                seriesScrollView
            }
        }
        .task {
            await loadSeries()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(
                    for:
                        .iptvConfigurationDidChange
                )
        ) { _ in
            Task {
                await loadSeries(
                    forceRefresh: true
                )
            }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(
                    for:
                        .iptvHomeRefreshRequested
                )
        ) { _ in
            Task {
                await loadSeries()
            }
        }
        .navigationDestination(
            isPresented:
                $showAllSeries
        ) {
            AllSeriesListView(
                seriesItems:
                    seriesItems
            )
        }
    }

    // MARK: - Header

    private var headerView:
        some View
    {
        VeyraSectionHeader(
            title:
                "IPTV nieuw toegevoegde series",
            subtitle:
                "Uit je zichtbare serielijsten"
        )
    }

    // MARK: - Loading

    private var loadingView:
        some View
    {
        ProgressView(
            "Series laden…"
        )
    }

    // MARK: - Error

    private func errorView(
        _ message:
            String
    ) -> some View {
        Text(message)
            .foregroundStyle(
                .orange
            )
    }

    // MARK: - Empty

    private var emptyView:
        some View
    {
        Text(
            "Geen nieuwe series gevonden (controleer zichtbare lijsten in instellingen)."
        )
        .foregroundStyle(
            .secondary
        )
        .padding(
            .vertical,
            20
        )
    }

    // MARK: - Horizontal Row

    private var seriesScrollView:
        some View
    {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            LazyHStack(
                alignment: .top,
                spacing:
                    VeyraSpacing.rail
            ) {
                ForEach(
                    seriesItems
                        .prefix(20)
                ) { item in
                    seriesLink(
                        item
                    )
                }

                toonAllesButton
            }
            .padding(12)
        }
        .scrollClipDisabled()
    }

    // MARK: - Series Link

    private func seriesLink(
        _ item:
            XtreamSeriesItem
    ) -> some View {
        NavigationLink {
            IPTVSeriesDetailView(
                series: item
            )

        } label: {
            VeyraPosterCard(
                title:
                    item.name,
                url:
                    item.coverURL,
                symbol:
                    "tv",
                width:
                    posterWidth
            )
        }
        .buttonStyle(
            VeyraFocusButtonStyle(
                radius:
                    VeyraRadius.poster
            )
        )
        .reportsHero(
            VeyraHeroContent(
                id: "iptv-series:\(item.id)",
                eyebrow: "Serie",
                title: item.name,
                overview: nil,
                metadata: [],
                backdropURL: item.coverURL
            )
        )
    }

    // MARK: - Show All

    private var toonAllesButton:
        some View
    {
        Button {
            showAllSeries =
                true

        } label: {
            VeyraPosterCard(
                title:
                    "Toon alles",
                url:
                    nil,
                symbol:
                    "arrow.right.circle",
                width:
                    posterWidth
            )
        }
        .buttonStyle(
            VeyraFocusButtonStyle(
                radius:
                    VeyraRadius.poster
            )
        )
    }

    // MARK: - Load Series

    @MainActor
    private func loadSeries(
        forceRefresh:
            Bool = false
    ) async {
        guard
            !isRefreshing
        else {
            return
        }

        isRefreshing =
            true

        defer {
            isRefreshing =
                false
        }

        errorMessage =
            nil

        do {
            let configStore =
                IPTVConfigurationStore()

            let preferencesStore =
                IPTVProviderPreferencesStore()

            guard
                let configuration =
                    try configStore
                        .load()
            else {
                seriesItems = []

                errorMessage =
                    "Geen IPTV-provider ingesteld."

                isLoading =
                    false

                return
            }

            let preferences =
                preferencesStore
                    .load(
                        for:
                            configuration
                    )

            let providerKey =
                configuration
                    .providerIdentifier

            let cacheKey =
                "recentlyAdded.series.\(providerKey)"

            if forceRefresh {
                seriesItems = []
            }

            // Cache onmiddellijk tonen.
            if seriesItems.isEmpty,
               let cached =
                IPTVDiskCache
                    .read(
                        [XtreamSeriesItem].self,
                        key:
                            cacheKey
                    )?
                    .value
            {
                seriesItems =
                    cached.filter {
                        preferences
                            .isSeriesItemVisible(
                                String(
                                    $0.id
                                )
                            )
                    }
            }

            isLoading =
                seriesItems.isEmpty

            guard
                case .xtream(
                    let xtreamConfig
                ) = configuration
            else {
                seriesItems = []

                errorMessage =
                    "Nieuw toegevoegd werkt alleen met Xtream series."

                isLoading =
                    false

                return
            }

            let service =
                IPTVService()

            let allSeries =
                try await service
                    .loadXtreamSeries(
                        configuration:
                            xtreamConfig,
                        categoryID:
                            nil
                    )

            try Task
                .checkCancellation()

            let visible =
                allSeries.filter {
                    series in

                    let categoryVisible:
                        Bool

                    if let categoryID =
                        series.categoryID,
                       !categoryID
                            .isEmpty
                    {
                        categoryVisible =
                            preferences
                                .isSeriesCategoryVisible(
                                    categoryID
                                )

                    } else {
                        categoryVisible =
                            true
                    }

                    return
                        categoryVisible
                        &&
                        preferences
                            .isSeriesItemVisible(
                                String(
                                    series.id
                                )
                            )
                }

            let sorted =
                visible.sorted {
                    if $0.id
                        != $1.id
                    {
                        return $0.id
                            > $1.id
                    }

                    return $0.name
                        .localizedStandardCompare(
                            $1.name
                        )
                        == .orderedAscending
                }

            seriesItems =
                sorted

            // Alleen de 200 nieuwste lokaal bewaren.
            let cachedRecentSeries =
                Array(
                    sorted.prefix(
                        200
                    )
                )

            IPTVDiskCache.write(
                cachedRecentSeries,
                key:
                    cacheKey
            )

        } catch is CancellationError {
            return

        } catch {
            if seriesItems.isEmpty {
                errorMessage =
                    error
                        .localizedDescription
            }
        }

        isLoading =
            false
    }
}

// MARK: - Custom tvOS Button Style

private struct VeyraSeriesButtonStyle:
    ButtonStyle
{
    func makeBody(
        configuration:
            Configuration
    ) -> some View {
        configuration.label
            .background(
                Color.clear
            )
            .opacity(
                configuration
                    .isPressed
                    ? 0.82
                    : 1
            )
    }
}

// MARK: - All Series List

struct AllSeriesListView: View {
    let seriesItems:
        [XtreamSeriesItem]

    @FocusState
    private var focusedSeriesID:
        Int?

    private let posterWidth:
        CGFloat = 220

    private let posterHeight:
        CGFloat = 330

    private let columns = [
        GridItem(
            .adaptive(
                minimum: 235
            ),
            spacing: 28
        )
    ]

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 22
            ) {
                headerView

                LazyVGrid(
                    columns:
                        columns,
                    spacing:
                        36
                ) {
                    ForEach(
                        seriesItems
                    ) { item in
                        seriesGridCell(
                            item
                        )
                    }
                }
                .padding(
                    .horizontal
                )
            }
            .padding(
                .vertical
            )
        }
        .navigationTitle(
            "IPTV nieuw toegevoegde series"
        )
    }

    // MARK: - Header

    private var headerView:
        some View
    {
        Label(
            "IPTV NIEUW TOEGEVOEGDE SERIES",
            systemImage:
                "sparkles"
        )
        .font(
            .system(
                size: 25,
                weight: .bold
            )
        )
        .tracking(2)
        .foregroundStyle(
            .cyan
        )
        .padding(
            .horizontal
        )
    }

    // MARK: - Grid Cell

    private func seriesGridCell(
        _ item:
            XtreamSeriesItem
    ) -> some View {
        let isFocused =
            focusedSeriesID
            == item.id

        return NavigationLink {
            IPTVSeriesDetailView(
                series: item
            )

        } label: {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                AsyncImage(
                    url:
                        item.coverURL
                ) { phase in
                    switch phase {
                    case .success(
                        let image
                    ):
                        image
                            .resizable()
                            .scaledToFill()

                    case .empty:
                        ZStack {
                            Color.white
                                .opacity(
                                    0.04
                                )

                            ProgressView()
                        }

                    case .failure:
                        posterFallback

                    @unknown default:
                        posterFallback
                    }
                }
                .frame(
                    width:
                        posterWidth,
                    height:
                        posterHeight
                )
                .clipped()
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            18,
                        style:
                            .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius:
                            18,
                        style:
                            .continuous
                    )
                    .strokeBorder(
                        isFocused
                            ? Color.cyan
                            : Color.clear,
                        lineWidth:
                            isFocused
                            ? 3
                            : 0
                    )
                )
                .scaleEffect(
                    isFocused
                        ? 1.04
                        : 1
                )
                .animation(
                    .easeOut(
                        duration:
                            0.14
                    ),
                    value:
                        isFocused
                )

                Text(
                    item.name
                )
                .font(
                    .system(
                        size: 20,
                        weight:
                            .semibold
                    )
                )
                .foregroundStyle(
                    .white
                )
                .lineLimit(2)
                .frame(
                    width:
                        posterWidth,
                    alignment:
                        .leading
                )
            }
            .frame(
                width:
                    posterWidth,
                alignment:
                    .topLeading
            )
        }
        .buttonStyle(
            VeyraSeriesButtonStyle()
        )
        .focused(
            $focusedSeriesID,
            equals:
                item.id
        )
        .focusEffectDisabled()
    }

    private var posterFallback:
        some View
    {
        ZStack {
            Color.white
                .opacity(
                    0.04
                )

            Image(
                systemName:
                    "tv"
            )
            .font(
                .system(
                    size: 58
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
    }
}

// MARK: - Series Detail

struct IPTVSeriesDetailView: View {
    let series:
        XtreamSeriesItem

    @State
    private var episodes:
        [XtreamSeriesEpisode] = []

    @State
    private var isLoading =
        true

    @State
    private var errorMessage:
        String?

    private let posterWidth:
        CGFloat = 220

    var body: some View {
        ScrollView(
            .vertical,
            showsIndicators: false
        ) {
            VStack(
                alignment: .leading,
                spacing: 32
            ) {
                if isLoading {
                    ProgressView(
                        "Afleveringen laden…"
                    )
                    .padding(
                        .horizontal
                    )

                } else if let errorMessage {
                    Text(
                        errorMessage
                    )
                    .foregroundStyle(
                        .orange
                    )
                    .padding(
                        .horizontal
                    )

                } else if episodes.isEmpty {
                    Text(
                        "Geen afleveringen gevonden."
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .padding(
                        .horizontal
                    )

                } else {
                    ForEach(
                        groupedBySeason,
                        id: \.season
                    ) { group in
                        seasonSection(
                            group
                        )
                    }
                }
            }
            .padding(
                .vertical
            )
        }
        .navigationTitle(
            series.name
        )
        .task {
            await loadEpisodes()
        }
    }

    // MARK: - Season Section

    private func seasonSection(
        _ group:
            (
                season: Int,
                episodes:
                    [XtreamSeriesEpisode]
            )
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            Text(
                "Seizoen \(group.season)"
            )
            .font(
                .system(
                    size: 24,
                    weight: .bold
                )
            )
            .padding(
                .horizontal
            )

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                LazyHStack(
                    alignment: .top,
                    spacing:
                        VeyraSpacing.rail
                ) {
                    ForEach(
                        group.episodes
                    ) { episode in
                        episodeLink(
                            episode
                        )
                    }
                }
                .padding(12)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Episode Link

    private func episodeLink(
        _ episode:
            XtreamSeriesEpisode
    ) -> some View {
        let code =
            String(
                format:
                    "S%02dE%02d",
                episode
                    .seasonNumber,
                episode
                    .episodeNumber
            )

        return NavigationLink {
            PlayerView(
                source:
                    IPTVService()
                        .playableSource(
                            for:
                                episode,
                            seriesName:
                                series.name
                        )
            )

        } label: {
            VeyraPosterCard(
                title:
                    "\(code) · \(episode.title)",
                url:
                    series.coverURL,
                symbol:
                    "tv",
                width:
                    posterWidth
            )
        }
        .buttonStyle(
            VeyraFocusButtonStyle(
                radius:
                    VeyraRadius.poster
            )
        )
    }

    // MARK: - Grouping

    private var groupedBySeason:
        [
            (
                season: Int,
                episodes:
                    [XtreamSeriesEpisode]
            )
        ]
    {
        let grouped =
            Dictionary(
                grouping:
                    episodes,
                by: {
                    $0.seasonNumber
                }
            )

        return grouped.keys
            .sorted()
            .map {
                season in

                (
                    season,
                    grouped[season]!
                        .sorted {
                            $0.episodeNumber
                                < $1.episodeNumber
                        }
                )
            }
    }

    // MARK: - Load Episodes

    @MainActor
    private func loadEpisodes()
        async
    {
        errorMessage =
            nil

        do {
            let configStore =
                IPTVConfigurationStore()

            guard
                let configuration =
                    try configStore.load(),
                case .xtream(
                    let xtreamConfig
                ) = configuration
            else {
                errorMessage =
                    "Geen Xtream IPTV-provider ingesteld."

                isLoading =
                    false

                return
            }

            let info =
                try await IPTVService()
                    .loadXtreamSeriesInfo(
                        configuration:
                            xtreamConfig,
                        seriesID:
                            series.id
                    )

            episodes =
                info.episodes

        } catch {
            errorMessage =
                error
                    .localizedDescription
        }

        isLoading =
            false
    }
}

#Preview {
    NavigationStack {
        IPTVRecentlyAddedSeriesRow()
            .padding()
            .background(
                Color.black
            )
    }
}
