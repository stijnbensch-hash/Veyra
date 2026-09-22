import SwiftUI

struct SeasonView: View {
    let series: TMDBSeriesDetails
    let season: TMDBSeason

    @State
    private var details:
        TMDBSeasonDetails?

    @State
    private var imdbID:
        String?

    @State
    private var isLoading =
        true

    @State
    private var errorMessage:
        String?

    @FocusState
    private var focusedEpisodeNumber:
        Int?

    // "Verder kijken"-voortgang per aflevering (Trakt playback-status),
    // zodat een gedeeltelijk bekeken aflevering een voortgangsbalkje en
    // een "Verder kijken"-label krijgt, net als op Home.
    @ObservedObject
    private var traktStore = TraktStore.shared

    private let imageBaseURL =
        URL(
            string:
                "https://image.tmdb.org/t/p/"
        )!

    var body: some View {
        ZStack {
            baseBackground
                .ignoresSafeArea()

            if isLoading {
                ProgressView(
                    "Afleveringen laden…"
                )
                .font(
                    .system(
                        size: 28
                    )
                )

            } else if let errorMessage {
                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {
                    Text(
                        "Afleveringen konden niet worden geladen"
                    )
                    .font(
                        .system(
                            size: 28
                        )
                    )

                    Text(
                        errorMessage
                    )
                    .font(
                        .system(
                            size: 18
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

            } else if let details {
                episodeContent(
                    details
                )
            }
        }
        .navigationTitle(
            season.name
        )
        .task {
            await loadSeason()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func episodeContent(
        _ details:
            TMDBSeasonDetails
    ) -> some View {
        ScrollView(
            .vertical,
            showsIndicators: false
        ) {
            VStack(
                alignment: .leading,
                spacing: 30
            ) {
                // Poster verwijderd.
                VStack(
                    alignment: .leading,
                    spacing: 14
                ) {
                    Text(
                        series.name
                    )
                    .font(
                        .system(
                            size: 44,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        .white
                    )
                    .lineLimit(2)

                    if let overview =
                        details.overview,
                       !overview.isEmpty
                    {
                        Text(
                            overview
                        )
                        .font(
                            .system(
                                size: 22
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(0.72)
                        )
                        .lineSpacing(4)
                        .lineLimit(6)
                        .frame(
                            maxWidth: 1200,
                            alignment: .leading
                        )
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

                VeyraSectionHeader(
                    title:
                        "Afleveringen",
                    subtitle:
                        "\(details.episodes.count) in dit seizoen"
                )

                LazyVStack(
                    spacing: 18
                ) {
                    ForEach(
                        details.episodes
                            .sorted {
                                $0.episodeNumber
                                    < $1.episodeNumber
                            }
                    ) { episode in

                        NavigationLink {
                            SourceSelectionView(
                                item:
                                    mediaItem(
                                        for:
                                            episode
                                    )
                            )

                        } label: {
                            episodeRow(
                                episode,
                                isFocused:
                                    focusedEpisodeNumber
                                    == episode
                                        .episodeNumber
                            )
                            .traktWatched(
                                .episode(
                                    show:
                                        TraktIDs(
                                            tmdb:
                                                series.id
                                        ),
                                    season:
                                        episode
                                            .seasonNumber,
                                    number:
                                        episode
                                            .episodeNumber
                                )
                            )
                        }
                        .buttonStyle(
                            VeyraEpisodeButtonStyle()
                        )
                        .focused(
                            $focusedEpisodeNumber,
                            equals:
                                episode
                                    .episodeNumber
                        )
                        .focusEffectDisabled()
                        .traktMarkWatchedMenu(
                            MediaItem(
                                title:
                                    series.name,

                                type:
                                    .series,

                                imdbID:
                                    imdbID,

                                tmdbID:
                                    series.id,

                                episodeTMDBID:
                                    episode.id,

                                seasonNumber:
                                    episode
                                        .seasonNumber,

                                episodeNumber:
                                    episode
                                        .episodeNumber
                            )
                        )
                    }
                }
                .focusSection()
            }
            .padding(
                .horizontal,
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
        .contentMargins(
            .top,
            150,
            for: .scrollContent
        )
        .scrollClipDisabled()
    }

    // MARK: - Media item

    private func mediaItem(
        for episode:
            TMDBEpisode
    ) -> MediaItem {
        MediaItem(
            title:
                series.name,

            type:
                .series,

            imdbID:
                imdbID,

            tmdbID:
                series.id,

            episodeTMDBID:
                episode.id,

            seasonNumber:
                episode
                    .seasonNumber,

            episodeNumber:
                episode
                    .episodeNumber,

            overview:
                episode.overview,

            releaseDate:
                episode.airDate,

            posterURL:
                imageURL(
                    path:
                        episode
                            .stillPath,
                    size:
                        "w500"
                ),

            backdropURL:
                seriesBackdropURL
        )
    }

    // MARK: - Episode row

    @ViewBuilder
    private func episodeRow(
        _ episode:
            TMDBEpisode,
        isFocused:
            Bool
    ) -> some View {
        HStack(
            spacing: 25
        ) {
            ZStack(alignment: .bottom) {
                AsyncImage(
                    url:
                        imageURL(
                            path:
                                episode
                                    .stillPath,
                            size:
                                "w500"
                        )
                ) { phase in
                    switch phase {
                    case .empty:
                        episodePlaceholder
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
                        episodePlaceholder

                    @unknown default:
                        episodePlaceholder
                    }
                }

                if let progress = watchProgress(for: episode) {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(VeyraColors.cyan)
                            .frame(width: geometry.size.width * progress / 100, height: 5)
                    }
                    .frame(height: 5)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
            }
            .frame(
                width: 280,
                height: 158
            )
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )

            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                HStack(
                    spacing: 13
                ) {
                    Text(
                        String(
                            format:
                                "%02d",
                            episode
                                .episodeNumber
                        )
                    )
                    .font(
                        .system(
                            size: 17,
                            weight: .bold,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(
                        isFocused
                            ? .black
                            : VeyraColors.ice
                    )
                    .frame(
                        width: 44,
                        height: 32
                    )
                    .background(
                        isFocused
                            ? VeyraColors.cyan
                            : VeyraColors.cyan
                                .opacity(0.13),
                        in:
                            RoundedRectangle(
                                cornerRadius: 9,
                                style: .continuous
                            )
                    )

                    Text(
                        episode.name
                    )
                    .font(
                        .system(
                            size: 28,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        .white
                    )
                    .lineLimit(1)

                    if watchProgress(for: episode) != nil {
                        Text("Verder kijken")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VeyraColors.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                VeyraColors.cyan.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    }
                }

                if let overview =
                    episode.overview,
                   !overview.isEmpty
                {
                    Text(
                        overview
                    )
                    .font(
                        .system(
                            size: 23
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.65)
                    )
                    .lineLimit(3)
                    .lineSpacing(3)
                }

                if let airDate =
                    episode.airDate,
                   airDate.count >= 4
                {
                    Text(
                        String(
                            airDate.prefix(4)
                        )
                    )
                    .font(
                        .system(
                            size: 18
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.45)
                    )
                }
            }

            Spacer()

            Image(
                systemName:
                    "chevron.right"
            )
            .font(
                .system(
                    size: 20,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                isFocused
                    ? Color.cyan
                    : Color.white
                        .opacity(0.45)
            )
        }
        .padding(18)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(
                            isFocused
                            ? 0.14
                            : 0.05
                        ),

                        VeyraColors
                            .surface
                            .opacity(0.82),

                        isFocused
                            ? VeyraColors.red
                                .opacity(0.08)
                            : Color.clear
                    ],
                    startPoint:
                        .topLeading,
                    endPoint:
                        .bottomTrailing
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 18,
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
                            .white.opacity(0.08)
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
        .scaleEffect(
            isFocused
            ? 1.02
            : 1
        )
        .shadow(
            color:
                isFocused
                    ? VeyraColors.cyan
                        .opacity(0.24)
                    : .black.opacity(0.20),
            radius:
                isFocused
                ? 17
                : 8,
            x: -4,
            y: 6
        )
        .shadow(
            color:
                isFocused
                    ? VeyraColors.red
                        .opacity(0.14)
                    : .clear,
            radius: 15,
            x: 8,
            y: 4
        )
        .animation(
            .easeOut(
                duration: 0.14
            ),
            value:
                isFocused
        )
        .contentShape(
            Rectangle()
        )
    }

    // MARK: - Placeholder

    private var episodePlaceholder:
        some View
    {
        ZStack {
            Color.white
                .opacity(0.08)

            Image(
                systemName:
                    "play.rectangle"
            )
            .font(
                .system(
                    size: 54
                )
            )
            .foregroundStyle(
                .white.opacity(0.35)
            )
        }
    }

    // MARK: - Background

    private var baseBackground:
        some View
    {
        VeyraBackground()
    }

    // MARK: - Artwork

    private var seriesBackdropURL:
        URL?
    {
        imageURL(
            path:
                series.backdropPath,
            size:
                "w1280"
        )
    }

    // MARK: - Voortgang

    /// Trakt-afspeelvoortgang (0-100) voor deze aflevering, als er
    /// gepauzeerd is met minder dan 100% bekeken. `nil` als er niets
    /// bekend is, of als de aflevering al (bijna) helemaal is afgespeeld.
    private func watchProgress(for episode: TMDBEpisode) -> Double? {
        guard let entry = traktStore.playback.first(where: { entry in
            guard let entryEpisode = entry.episode,
                  entryEpisode.season == episode.seasonNumber,
                  entryEpisode.number == episode.episodeNumber
            else { return false }

            let showIDs = entry.show?.ids
            if let tmdb = showIDs?.tmdb, tmdb == series.id { return true }
            if let imdb = showIDs?.imdb, let imdbID, !imdbID.isEmpty, imdb == imdbID { return true }
            return false
        }) else { return nil }

        guard let progress = entry.progress, progress.isFinite, progress > 0, progress < 100 else {
            return nil
        }
        return progress
    }

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
                path
                    .trimmingCharacters(
                        in:
                            CharacterSet(
                                charactersIn:
                                    "/"
                            )
                    )
            )
    }

    // MARK: - Load season

    @MainActor
    private func loadSeason()
        async
    {
        isLoading =
            true

        errorMessage =
            nil

        guard
            let service =
                SeriesService()
        else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."

            isLoading =
                false

            return
        }

        do {
            async let seasonRequest =
                service.season(
                    seriesID:
                        series.id,
                    seasonNumber:
                        season.seasonNumber
                )

            async let externalIDRequest =
                service.externalIDs(
                    forSeriesID:
                        series.id
                )

            let (
                loadedSeason,
                externalIDs
            ) =
                try await (
                    seasonRequest,
                    externalIDRequest
                )

            try Task
                .checkCancellation()

            details =
                loadedSeason

            imdbID =
                externalIDs.imdbID

        } catch is CancellationError {
            return

        } catch {
            errorMessage =
                error.localizedDescription
        }

        isLoading =
            false
    }
}

// MARK: - Episode button style

private struct VeyraEpisodeButtonStyle:
    ButtonStyle
{
    func makeBody(
        configuration:
            Configuration
    ) -> some View {
        configuration.label
            .opacity(
                configuration
                    .isPressed
                ? 0.82
                : 1
            )
            .scaleEffect(
                configuration
                    .isPressed
                ? 0.985
                : 1
            )
            .animation(
                .easeOut(
                    duration: 0.12
                ),
                value:
                    configuration
                        .isPressed
            )
    }
}

#Preview {
    NavigationStack {
        SeasonView(
            series:
                TMDBSeriesDetails(
                    id: 1399,
                    name:
                        "Game of Thrones",
                    overview:
                        "Voorbeeldserie.",
                    posterPath:
                        nil,
                    backdropPath:
                        nil,
                    firstAirDate:
                        "2011-04-17",
                    voteAverage:
                        8.4,
                    numberOfSeasons:
                        8,
                    seasons:
                        []
                ),

            season:
                TMDBSeason(
                    id: 3627,
                    name:
                        "Seizoen 1",
                    overview:
                        nil,
                    seasonNumber:
                        1,
                    posterPath:
                        nil,
                    episodeCount:
                        10
                )
        )
    }
}
