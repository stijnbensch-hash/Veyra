import SwiftUI

struct SeriesView: View {
    @ObservedObject private var trakt = TraktStore.shared

    @State private var series: [TMDBSeries] = []
    @State private var selectedSeries: TMDBSeries?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedProvider: WatchProvider?
    @State private var selectedGenreID: Int?
    @State private var selectedDecade: VeyraDecadeFilter?
    @State private var selectedRating: VeyraRatingFilter?
    @State private var selectedSort: VeyraSortOption = .newest

    @AppStorage("catalog.watchRegion")
    private var watchRegion = "BE"
    @AppStorage(TMDBCatalogLanguageFilter.key)
    private var catalogLanguages = "nl-en"

    @State private var catalogRequestID = UUID()

    // Automatisch roterende hero: elke paar seconden een andere titel uit
    // de populairste series.
    @State private var heroRotationIndex = 0

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var metrics: VeyraPosterMetrics { VeyraPosterMetrics(regular: sizeClass == .regular) }
    private var columns: [GridItem] { metrics.columns }

    private let posterBaseURL =
        URL(string: "https://image.tmdb.org/t/p/w500")!

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraArtworkBackground(
                    url: featured?.backdropPath.flatMap {
                        URL(
                            string:
                                "https://image.tmdb.org/t/p/w1280"
                                + $0
                        )
                    }
                )
                .id(featured?.id ?? -1)
                .animation(.easeInOut(duration: 0.35), value: featured?.id)

                ScrollView(
                    .vertical,
                    showsIndicators: false
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 24
                    ) {
                        if let featured {
                            VeyraHero(
                                title: featured.name,
                                eyebrow: "Serie uitgelicht",
                                overview: featured.overview,
                                metadata:
                                    featured.firstAirDate.map {
                                        [
                                            String(
                                                $0.prefix(4)
                                            )
                                        ]
                                    }
                                    ?? []
                            ) {
                                Button {
                                    selectedSeries = featured
                                } label: {
                                    VeyraActionLabel(
                                        title:
                                            "Afleveringen bekijken",
                                        symbol:
                                            "play.rectangle"
                                    )
                                }
                                .buttonStyle(.plain)
                                .background(
                                    .white.opacity(0.14),
                                    in: Capsule()
                                )
                            }
                        }

                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {
                            header

                            MediaFiltersRowIOS(
                                kind: .tv,
                                selectedGenreID:
                                    $selectedGenreID,
                                selectedDecade:
                                    $selectedDecade,
                                selectedRating:
                                    $selectedRating,
                                selectedSort:
                                    $selectedSort
                            )
                        }

                        content
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(
                .hidden,
                for: .navigationBar
            )
            .onChange(
                of: watchRegion
            ) { _, _ in
                selectedProvider = nil
            }
            .task(
                id: catalogTaskID
            ) {
                async let catalogTask: Void =
                    loadSeries()

                async let traktTask: Void =
                    refreshTrakt()

                _ = await (
                    catalogTask,
                    traktTask
                )
            }
            .task(id: heroPool.map(\.id)) {
                await rotateHeroAutomatically()
            }
            .navigationDestination(
                item: $selectedSeries
            ) { series in
                SeriesDetailView(
                    series: series
                )
            }
        }
    }

    // MARK: - Hero rotatie

    private var heroPool: [TMDBSeries] {
        Array(series.prefix(10))
    }

    private var featured: TMDBSeries? {
        guard !heroPool.isEmpty else { return nil }
        return heroPool[heroRotationIndex % heroPool.count]
    }

    private func rotateHeroAutomatically() async {
        heroRotationIndex = 0
        guard heroPool.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            heroRotationIndex = (heroRotationIndex + 1) % heroPool.count
        }
    }

    // MARK: - Header

    private var header: some View {
        VeyraSectionHeader(
            title: "Series",
            subtitle: filterSummary
        )
    }

    private var filterSummary: String {
        var parts: [String] = [selectedSort.displayName]

        if let selectedProvider {
            parts.append(
                selectedProvider.name
            )
        }

        if let selectedGenreID,
           let name =
            TMDBGenreNames.tvName(
                for: selectedGenreID
            )
        {
            parts.append(name)
        }

        if let selectedDecade {
            parts.append(
                selectedDecade.title
            )
        }

        if let selectedRating {
            parts.append(
                selectedRating.title
            )
        }

        parts.append(watchRegion)

        return parts.joined(
            separator: " · "
        )
    }

    private var catalogTaskID: String {
        [
            watchRegion,
            catalogLanguages,
            selectedProvider?
                .id
                .description
                ?? "-",
            selectedGenreID?
                .description
                ?? "-",
            selectedDecade?
                .id
                ?? "-",
            selectedRating.map {
                String($0.rawValue)
            }
            ?? "-",
            selectedSort.rawValue,
        ]
        .joined(
            separator: "|"
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading
            && series.isEmpty
        {
            ProgressView(
                "Series laden…"
            )
            .padding(.top, 20)
            .frame(
                maxWidth: .infinity
            )

        } else if
            let errorMessage,
            series.isEmpty
        {
            errorView(
                errorMessage
            )

        } else if
            series.isEmpty
        {
            ContentUnavailableView(
                "Geen series beschikbaar",
                systemImage: "tv"
            )

        } else {
            LazyVGrid(
                columns: columns,
                spacing: metrics.rowSpacing
            ) {
                ForEach(series) {
                    item in

                    Button {
                        selectedSeries = item
                    } label: {
                        VeyraPosterCard(
                            title:
                                item.name,
                            url:
                                posterURL(
                                    for: item
                                ),
                            symbol: "tv",
                            width: metrics.posterWidth,
                            genre:
                                TMDBGenreNames
                                .firstTVName(
                                    for:
                                        item.genreIDs
                                        ?? []
                                ),
                            rating:
                                item.voteAverage,
                            year: String(item.firstAirDate?.prefix(4) ?? ""),
                            tmdbID: item.id,
                            isMovie: false,
                            releaseDateRaw: item.firstAirDate,
                            watchedTarget: .show(TraktIDs(tmdb: item.id)),
                            watchedPartialDisplay: .remaining
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Error

    private func errorView(
        _ message: String
    ) -> some View {
        VStack(
            spacing: 12
        ) {
            Text(
                "Series konden niet worden geladen"
            )
            .font(.headline)
            .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )

            Button(
                "Opnieuw proberen"
            ) {
                Task {
                    await loadSeries()
                }
            }
        }
        .padding()
        .frame(
            maxWidth: .infinity
        )
    }

    // MARK: - Poster

    private func posterURL(
        for series: TMDBSeries
    ) -> URL? {
        guard let path =
            series.posterPath
        else {
            return nil
        }

        return posterBaseURL
            .appendingPathComponent(
                path
                    .trimmingCharacters(
                        in:
                            CharacterSet(
                                charactersIn: "/"
                            )
                    )
            )
    }

    // MARK: - Load series

    @MainActor
    private func loadSeries()
        async
    {
        let requestID = UUID()

        catalogRequestID =
            requestID

        isLoading = true
        errorMessage = nil

        guard
            let service =
                SeriesService(),
            let token =
                AppConfiguration
                .tmdbReadAccessToken
        else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."

            isLoading = false
            return
        }

        do {
            let result:
                [TMDBSeries]

            switch selectedSort {
            case .trending:
                // TMDB's trending-endpoint ondersteunt geen discover-filters
                // (provider/genre/decennium/beoordeling); bekende beperking:
                // bij "Trending" worden overige filters genegeerd.
                result =
                    try await service
                    .trendingSeries()

            case .popular:
                if selectedProvider != nil
                    || selectedGenreID != nil
                    || selectedDecade != nil
                    || selectedRating != nil
                {
                    result =
                        try await TMDBClient(
                            readAccessToken:
                                token
                        )
                        .series(
                            providerID:
                                selectedProvider?.id,
                            region:
                                watchRegion,
                            genreID:
                                selectedGenreID,
                            minimumYear:
                                selectedDecade?.startYear,
                            maximumYear:
                                selectedDecade?.endYear,
                            minimumRating:
                                selectedRating?.rawValue,
                            sortBy:
                                "popularity.desc"
                        )

                } else {
                    result =
                        try await service
                        .popularSeries()
                }

            case .topRated:
                result =
                    try await TMDBClient(
                        readAccessToken:
                            token
                    )
                    .series(
                        providerID:
                            selectedProvider?.id,
                        region:
                            watchRegion,
                        genreID:
                            selectedGenreID,
                        minimumYear:
                            selectedDecade?.startYear,
                        maximumYear:
                            selectedDecade?.endYear,
                        minimumRating:
                            selectedRating?.rawValue,
                        sortBy:
                            "vote_average.desc"
                    )

            case .newest:
                // Zelfde recent-uitgebracht-lijst (laatste 60 dagen, op
                // populariteit) als de "Nieuwe series"-rij op Home.
                result =
                    try await TMDBClient(
                        readAccessToken:
                            token
                    )
                    .series(
                        providerID:
                            selectedProvider?.id,
                        region:
                            watchRegion,
                        genreID:
                            selectedGenreID,
                        minimumYear:
                            selectedDecade?.startYear,
                        maximumYear:
                            selectedDecade?.endYear,
                        minimumRating:
                            selectedRating?.rawValue,
                        sortBy:
                            "popularity.desc",
                        recentDays:
                            selectedDecade == nil ? 60 : nil
                    )
            }

            try Task
                .checkCancellation()

            guard
                catalogRequestID
                    == requestID
            else {
                return
            }

            series = result

        } catch {
            guard
                !Task.isCancelled,
                catalogRequestID
                    == requestID
            else {
                return
            }

            errorMessage =
                error.localizedDescription
        }

        if catalogRequestID
            == requestID
        {
            isLoading = false
        }
    }

    // MARK: - Trakt

    @MainActor
    private func refreshTrakt()
        async
    {
        guard
            trakt.isConnected
        else {
            return
        }

        await trakt
            .refreshIfNeeded()
    }
}

#Preview {
    SeriesView()
}
