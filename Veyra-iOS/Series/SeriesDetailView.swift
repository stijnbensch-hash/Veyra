import SwiftUI

struct SeriesDetailView: View {
    let series: TMDBSeries

    @ObservedObject private var trakt =
        TraktStore.shared

    @StateObject private var viewModel:
        SeriesDetailViewModel

    @State private var ratings =
        MetadataRatings()

    init(
        series: TMDBSeries
    ) {
        self.series = series

        _viewModel =
            StateObject(
                wrappedValue:
                    SeriesDetailViewModel(
                        seriesID: series.id
                    )
            )
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                backdrop

                VStack(
                    alignment: .leading,
                    spacing: 14
                ) {
                    if viewModel.isLoading {
                        ProgressView(
                            "Serie laden…"
                        )

                    } else if
                        let errorMessage =
                            viewModel.errorMessage
                    {
                        Text(
                            "Serie kon niet worden geladen"
                        )
                        .font(.headline)

                        Text(
                            errorMessage
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            .secondary
                        )

                    } else if
                        let details =
                            viewModel.details
                    {
                        HStack(
                            alignment: .center,
                            spacing: 10
                        ) {
                            Text(
                                details.name
                            )
                            .font(
                                .title
                                    .weight(
                                        .bold
                                    )
                            )

                            if hasAnyWatchedEpisode {
                                watchedBadge
                            }
                        }

                        if let year =
                            releaseYear(
                                from:
                                    details
                                    .firstAirDate
                            )
                        {
                            Text(year)
                                .font(
                                    .subheadline
                                )
                                .foregroundStyle(
                                    VeyraColors
                                        .cyan
                                )
                        }

                        MetadataRatingsView(
                            ratings:
                                ratings
                        )

                        if !details
                            .overview
                            .isEmpty
                        {
                            Text(
                                details
                                    .overview
                            )
                            .font(.body)
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        WatchlistToggleButton(
                            item:
                                mediaItem(
                                    from:
                                        details
                                )
                        )

                        let seasons =
                            details.seasons
                                .filter {
                                    $0.seasonNumber
                                        > 0
                                }

                        if !seasons.isEmpty {
                            Text(
                                "Seizoenen"
                            )
                            .font(
                                .headline
                            )
                            .padding(
                                .top,
                                8
                            )

                            ForEach(
                                seasons
                            ) { season in
                                NavigationLink {
                                    SeasonEpisodesView(
                                        series:
                                            details,
                                        season:
                                            season
                                    )

                                } label: {
                                    HStack(
                                        spacing: 12
                                    ) {
                                        Text(
                                            "Seizoen \(season.seasonNumber)"
                                        )

                                        if isSeasonWatched(
                                            seasonNumber:
                                                season.seasonNumber,
                                            episodeCount:
                                                season.episodeCount
                                        ) {
                                            watchedBadge
                                        }

                                        Spacer()

                                        Text(
                                            "\(season.episodeCount) afl."
                                        )
                                        .foregroundStyle(
                                            .secondary
                                        )

                                        Image(
                                            systemName:
                                                "chevron.right"
                                        )
                                        .font(
                                            .caption
                                        )
                                        .foregroundStyle(
                                            .secondary
                                        )
                                    }
                                    .font(
                                        .subheadline
                                    )
                                    .foregroundStyle(
                                        .primary
                                    )
                                    .contentShape(
                                        Rectangle()
                                    )
                                }
                                .buttonStyle(
                                    .plain
                                )

                                Divider()
                            }
                        }
                    }
                }
                .padding(
                    .horizontal
                )
            }
            .padding(
                .bottom,
                40
            )
        }
        .background(
            VeyraColors
                .background
                .ignoresSafeArea()
        )
        .navigationTitle(
            series.name
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .ignoresSafeArea(
            edges: .top
        )
        .task {
            async let detailsTask:
                Void =
                viewModel.loadDetails()

            async let traktTask:
                Void =
                refreshTrakt()

            _ = await (
                detailsTask,
                traktTask
            )
        }
        .task(
            id: series.id
        ) {
            ratings =
                await MetadataRatingsService
                    .seriesRatings(
                        tmdbID:
                            series.id,
                        imdbID:
                            nil
                    )
        }
    }

    // MARK: - Backdrop

    private var backdrop:
        some View
    {
        AsyncImage(
            url:
                imageURL(
                    path:
                        viewModel
                        .details?
                        .backdropPath
                        ?? series
                        .backdropPath,
                    size:
                        "w1280"
                )
        ) { phase in
            switch phase {
            case .success(
                let image
            ):
                image
                    .resizable()
                    .scaledToFill()

            default:
                VeyraColors
                    .surface
            }
        }
        .frame(
            height: 220
        )
        .clipped()
    }

    // MARK: - Watched

    private var watchedBadge:
        some View
    {
        ZStack {
            Circle()
                .fill(
                    .ultraThinMaterial
                )

            Circle()
                .stroke(
                    VeyraColors
                        .cyan
                        .opacity(
                            0.95
                        ),
                    lineWidth:
                        1.5
                )

            Image(
                systemName:
                    "checkmark"
            )
            .font(
                .system(
                    size: 11,
                    weight:
                        .bold
                )
            )
            .foregroundStyle(
                VeyraColors
                    .cyan
            )
        }
        .frame(
            width: 26,
            height: 26
        )
        .shadow(
            color:
                .black.opacity(
                    0.35
                ),
            radius: 5,
            y: 2
        )
        .accessibilityLabel(
            "Bekeken"
        )
    }

    private var watchedEntry:
        TraktEntry?
    {
        trakt.watchedShows
            .first {
                $0.show?
                    .ids
                    .tmdb
                    == series.id
            }
    }

    private var hasAnyWatchedEpisode:
        Bool
    {
        guard let seasons =
            watchedEntry?
                .seasons
        else {
            return false
        }

        return seasons
            .contains {
                season in

                season.episodes
                    .contains {
                        episode in

                        (
                            episode
                                .plays
                                ?? 1
                        ) > 0
                    }
            }
    }

    private func isSeasonWatched(
        seasonNumber: Int,
        episodeCount: Int
    ) -> Bool {
        guard
            episodeCount > 0,
            let season =
                watchedEntry?
                    .seasons?
                    .first(
                        where: {
                            $0.number
                                == seasonNumber
                        }
                    )
        else {
            return false
        }

        let watchedEpisodeNumbers =
            Set(
                season.episodes
                    .filter {
                        (
                            $0.plays
                                ?? 1
                        ) > 0
                    }
                    .map(
                        \.number
                    )
            )

        return watchedEpisodeNumbers
            .count
            >= episodeCount
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

    // MARK: - Helpers

    private func imageURL(
        path: String?,
        size: String
    ) -> URL? {
        guard
            let path,
            !path.isEmpty
        else {
            return nil
        }

        return URL(
            string:
                "https://image.tmdb.org/t/p/\(size)\(path)"
        )
    }

    private func releaseYear(
        from date: String?
    ) -> String? {
        guard
            let date,
            date.count >= 4
        else {
            return nil
        }

        return String(
            date.prefix(4)
        )
    }

    private func mediaItem(
        from details:
            TMDBSeriesDetails
    ) -> MediaItem {
        MediaItem(
            title:
                details.name,
            type:
                .series,
            tmdbID:
                series.id,
            overview:
                details.overview,
            releaseDate:
                details.firstAirDate,
            backdropURL:
                imageURL(
                    path:
                        details
                        .backdropPath
                        ?? series
                        .backdropPath,
                    size:
                        "w1280"
                )
        )
    }
}
