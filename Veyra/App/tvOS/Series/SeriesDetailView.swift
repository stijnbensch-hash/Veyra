import SwiftUI

struct SeriesDetailView: View {
    let series: TMDBSeries

    @StateObject
    private var viewModel:
        SeriesDetailViewModel

    @FocusState
    private var focusedSeasonNumber:
        Int?

    @State private var ratings = MetadataRatings()

    private let imageBaseURL =
        URL(
            string:
                "https://image.tmdb.org/t/p/"
        )!

    init(
        series: TMDBSeries
    ) {
        self.series =
            series

        _viewModel =
            StateObject(
                wrappedValue:
                    SeriesDetailViewModel(
                        seriesID:
                            series.id
                    )
            )
    }

    var body: some View {
        ZStack {
            background

            LinearGradient(
                colors: [
                    .black.opacity(0.15),
                    .black.opacity(0.55),
                    Color(
                        red: 0.01,
                        green: 0.04,
                        blue: 0.07
                    )
                ],
                startPoint:
                    .topTrailing,
                endPoint:
                    .bottomLeading
            )
            .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView(
                    "Serie laden…"
                )
                .font(.title3)

            } else if let errorMessage =
                viewModel.errorMessage
            {
                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {
                    Text(
                        "Serie kon niet worden geladen"
                    )
                    .font(.title2)

                    Text(
                        errorMessage
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

            } else if let details =
                viewModel.details
            {
                detailContent(
                    details
                )
            }
        }
        .task {
            await viewModel
                .loadDetails()
        }
        .task(id: series.id) {
            ratings = await MetadataRatingsService.seriesRatings(
                tmdbID: series.id, imdbID: nil
            )
        }
        .task {
            await TraktStore
                .shared
                .refreshIfNeeded()
        }
    }

    // MARK: - Detail content

    @ViewBuilder
    private func detailContent(
        _ details:
            TMDBSeriesDetails
    ) -> some View {
        ScrollView(
            .vertical,
            showsIndicators: false
        ) {
            VStack(
                alignment: .leading,
                spacing: 42
            ) {
                HStack(
                    alignment: .top,
                    spacing: 45
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 24
                    ) {
                        Text(
                            details.name
                        )
                        .font(
                            .system(
                                size: 54,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(
                            .white
                        )
                        .lineLimit(2)

                        if let year =
                            releaseYear(
                                from:
                                    details
                                        .firstAirDate
                            )
                        {
                            Text(year)
                                .font(.title3)
                                .foregroundStyle(
                                    .cyan.opacity(0.85)
                                )
                        }

                        MetadataRatingsView(ratings: ratings)

                        if !details
                            .overview
                            .isEmpty
                        {
                            Text(
                                details.overview
                            )
                            .font(
                                .system(
                                    size: 26,
                                    weight: .regular
                                )
                            )
                            .foregroundStyle(
                                .white.opacity(0.82)
                            )
                            .lineSpacing(7)
                            .lineLimit(7)
                            .frame(
                                maxWidth: 1050,
                                alignment: .leading
                            )
                        }

                        Spacer()
                    }
                    .padding(.top, 30)
                    .frame(maxWidth: 1050, alignment: .leading)

                    Spacer(
                        minLength: 0
                    )
                }

                seasonsSection(
                    details
                )

                Spacer(
                    minLength: 20
                )
            }
            .padding(
                .horizontal,
                28
            )
            .padding(
                .top,
                28
            )
            .padding(
                .bottom,
                50
            )
        }
        .contentMargins(
            .horizontal,
            0,
            for: .scrollContent
        )
        .scrollClipDisabled()
    }

    // MARK: - Seasons

    @ViewBuilder
    private func seasonsSection(
        _ details:
            TMDBSeriesDetails
    ) -> some View {
        let seasons =
            details.seasons.filter {
                $0.seasonNumber > 0
            }

        if !seasons.isEmpty {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                VeyraSectionHeader(
                    title:
                        "Seizoenen",
                    subtitle:
                        "\(seasons.count) beschikbaar"
                )

                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    LazyHStack(
                        spacing: 26
                    ) {
                        ForEach(
                            seasons
                        ) { season in

                            NavigationLink {
                                SeasonView(
                                    series:
                                        details,
                                    season:
                                        season
                                )

                            } label: {
                                seasonCard(
                                    season,
                                    details:
                                        details,
                                    isFocused:
                                        focusedSeasonNumber
                                        == season
                                            .seasonNumber
                                )
                            }
                            .buttonStyle(
                                VeyraSeasonButtonStyle()
                            )
                            .focused(
                                $focusedSeasonNumber,
                                equals:
                                    season
                                        .seasonNumber
                            )
                            .focusEffectDisabled()
                        }
                    }
                    .padding(
                        .horizontal,
                        6
                    )
                    .padding(
                        .vertical,
                        22
                    )
                }
                .contentMargins(
                    .horizontal,
                    0,
                    for: .scrollContent
                )
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - Season landscape card

    private func seasonCard(
        _ season:
            TMDBSeason,
        details:
            TMDBSeriesDetails,
        isFocused:
            Bool
    ) -> some View {
        ZStack(
            alignment: .bottomLeading
        ) {
            SeasonLandscapeArtwork(
                seriesID:
                    series.id,
                seasonNumber:
                    season.seasonNumber,
                fallbackBackdropPath:
                    details.backdropPath
                    ?? series.backdropPath
            )

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.16),
                    .black.opacity(0.94)
                ],
                startPoint:
                    .top,
                endPoint:
                    .bottom
            )

            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text(
                    "SEIZOEN \(season.seasonNumber)"
                )
                .font(
                    .system(
                        size: 24,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .tracking(1.4)
                .foregroundStyle(
                    VeyraColors.cyan
                )
                .lineLimit(1)

                Text(
                    "\(season.episodeCount) afleveringen"
                )
                .font(
                    .system(
                        size: 19,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.74)
                )
            }
            .padding(22)
        }
        .frame(
            width: 440,
            height: 248
        )
        .background(
            VeyraColors.surface
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                isFocused
                    ? LinearGradient(
                        colors: [
                            VeyraColors.ice,
                            VeyraColors.cyan,
                            VeyraColors.red
                        ],
                        startPoint:
                            .leading,
                        endPoint:
                            .trailing
                    )
                    : LinearGradient(
                        colors: [
                            .white.opacity(0.10)
                        ],
                        startPoint:
                            .leading,
                        endPoint:
                            .trailing
                    ),
                lineWidth:
                    isFocused
                        ? 3
                        : 1
            )
        }
        .shadow(
            color:
                isFocused
                    ? VeyraColors.cyan
                        .opacity(0.30)
                    : .black.opacity(0.25),
            radius:
                isFocused
                    ? 20
                    : 11,
            x: -4,
            y: 8
        )
        .shadow(
            color:
                isFocused
                    ? VeyraColors.red
                        .opacity(0.16)
                    : .clear,
            radius: 16,
            x: 8,
            y: 4
        )
        .scaleEffect(
            isFocused
                ? 1.04
                : 1
        )
        .animation(
            VeyraAnimation.focus,
            value:
                isFocused
        )
        .traktWatched(
            .season(
                show:
                    TraktIDs(
                        tmdb:
                            series.id
                    ),
                number:
                    season
                        .seasonNumber,
                episodeCount:
                    season
                        .episodeCount
            ),
            partialDisplay:
                .remaining
        )
    }

    // MARK: - Background

    @ViewBuilder
    private var background:
        some View
    {
        if let backdropURL =
            imageURL(
                path:
                    viewModel
                        .details?
                        .backdropPath
                    ?? series.backdropPath,
                size:
                    "w1280"
            )
        {
            AsyncImage(
                url:
                    backdropURL
            ) { phase in
                switch phase {
                case .empty:
                    baseBackground

                case .success(
                    let image
                ):
                    image
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()

                case .failure:
                    baseBackground

                @unknown default:
                    baseBackground
                }
            }

        } else {
            baseBackground
        }
    }

    private var baseBackground:
        some View
    {
        VeyraBackground()
    }

    // MARK: - Images

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

        return imageBaseURL
            .appendingPathComponent(
                size
            )
            .appendingPathComponent(
                path.trimmingCharacters(
                    in:
                        CharacterSet(
                            charactersIn: "/"
                        )
                )
            )
    }

    // MARK: - Date

    private func releaseYear(
        from date:
            String?
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
}

// MARK: - Season landscape artwork

private struct SeasonLandscapeArtwork: View {
    let seriesID: Int
    let seasonNumber: Int
    let fallbackBackdropPath: String?

    @State
    private var seasonStillPath:
        String?

    @State
    private var hasLoaded =
        false

    private let imageBaseURL =
        URL(
            string:
                "https://image.tmdb.org/t/p/"
        )!

    var body: some View {
        ZStack {
            if let artworkURL {
                AsyncImage(
                    url: artworkURL
                ) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                            .overlay {
                                ProgressView()
                            }

                    case .success(
                        let image
                    ):
                        image
                            .resizable()
                            .scaledToFill()

                    case .failure:
                        placeholder

                    @unknown default:
                        placeholder
                    }
                }

            } else {
                placeholder
            }
        }
        .frame(
            width: 440,
            height: 248
        )
        .clipped()
        .task(
            id:
                "\(seriesID)-\(seasonNumber)"
        ) {
            await loadSeasonArtwork()
        }
    }

    // MARK: Artwork URL

    private var artworkURL:
        URL?
    {
        if let seasonStillPath,
           !seasonStillPath.isEmpty
        {
            return imageURL(
                path:
                    seasonStillPath,
                size:
                    "w780"
            )
        }

        return imageURL(
            path:
                fallbackBackdropPath,
            size:
                "w780"
        )
    }

    // MARK: Load season artwork

    @MainActor
    private func loadSeasonArtwork()
        async
    {
        guard
            !hasLoaded
        else {
            return
        }

        hasLoaded =
            true

        guard
            let service =
                SeriesService()
        else {
            return
        }

        do {
            let season =
                try await service
                    .season(
                        seriesID:
                            seriesID,
                        seasonNumber:
                            seasonNumber
                    )

            try Task
                .checkCancellation()

            let sortedEpisodes =
                season.episodes
                    .sorted {
                        $0.episodeNumber
                            < $1.episodeNumber
                    }

            seasonStillPath =
                sortedEpisodes
                    .first {
                        guard
                            let path =
                                $0.stillPath
                        else {
                            return false
                        }

                        return !path.isEmpty
                    }?
                    .stillPath

        } catch is CancellationError {
            return

        } catch {
            seasonStillPath =
                nil
        }
    }

    // MARK: Image URL

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

        return imageBaseURL
            .appendingPathComponent(
                size
            )
            .appendingPathComponent(
                path.trimmingCharacters(
                    in:
                        CharacterSet(
                            charactersIn: "/"
                        )
                )
            )
    }

    // MARK: Placeholder

    private var placeholder:
        some View
    {
        ZStack {
            LinearGradient(
                colors: [
                    VeyraColors.surface,
                    Color.black.opacity(0.82)
                ],
                startPoint:
                    .topLeading,
                endPoint:
                    .bottomTrailing
            )

            Image(
                systemName:
                    "tv"
            )
            .font(
                .system(size: 64)
            )
            .foregroundStyle(
                .white.opacity(0.35)
            )
        }
    }
}

// MARK: - Season button style

private struct VeyraSeasonButtonStyle:
    ButtonStyle
{
    func makeBody(
        configuration:
            Configuration
    ) -> some View {
        configuration.label
            .scaleEffect(
                configuration
                    .isPressed
                    ? 0.96
                    : 1
            )
            .animation(
                .easeOut(
                    duration: 0.15
                ),
                value:
                    configuration
                        .isPressed
            )
    }
}

#Preview {
    NavigationStack {
        SeriesDetailView(
            series:
                TMDBSeries(
                    id: 1399,
                    name:
                        "Game of Thrones",
                    overview:
                        "Een voorbeeld van een seriedetailpagina.",
                    posterPath:
                        nil,
                    backdropPath:
                        nil,
                    firstAirDate:
                        "2011-04-17",
                    voteAverage:
                        8.4,
                    genreIDs:
                        nil
                )
        )
    }
}
