import SwiftUI

struct EpisodeView: View {
    let series: TMDBSeriesDetails
    let episode: TMDBEpisode

    @State private var imdbID: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let imageBaseURL = URL(
        string: "https://image.tmdb.org/t/p/"
    )!

    var body: some View {
        ZStack {
            background

            LinearGradient(
                colors: [
                    .black.opacity(0.25),
                    .black.opacity(0.72),
                    Color(
                        red: 0.01,
                        green: 0.04,
                        blue: 0.07
                    )
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            content
        }
        .task {
            await loadExternalIDs()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(
                "Aflevering laden…"
            )
            .font(
                .system(size: 30)
            )

        } else if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Text(
                    "Aflevering kon niet worden geladen"
                )
                .font(
                    .system(size: 30)
                )
                .foregroundStyle(
                    .white
                )

                Text(
                    errorMessage
                )
                .font(
                    .system(size: 28)
                )
                .foregroundStyle(
                    .secondary
                )
            }

        } else if let mediaItem {
            VStack(
                alignment: .leading,
                spacing: 26
            ) {
                HStack(spacing: 11) {
                    Capsule()
                        .fill(VeyraColors.red)
                        .frame(width: 26, height: 5)

                    Text(series.name.uppercased())
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(VeyraColors.ice.opacity(0.86))
                }

                Text(
                    episode.name
                )
                .font(
                    .system(
                        size: 60,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    .white
                )
                .lineLimit(2)

                HStack(spacing: 12) {
                    Text("Seizoen \(episode.seasonNumber)")
                    Text("Aflevering \(episode.episodeNumber)")

                    if let airDate = episode.formattedAirDate {
                        Text(airDate)
                    }
                }
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.28), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.10)))

                if
                    let overview =
                        episode.overview,
                    !overview
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
                {
                    Text(
                        overview
                    )
                    .font(
                        .system(
                            size: 32,
                            weight: .regular
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.82)
                    )
                    .lineSpacing(7)
                    .lineLimit(7)
                    .frame(
                        maxWidth: 900,
                        alignment: .leading
                    )
                }

                NavigationLink {
                    SourceSelectionView(
                        item: mediaItem
                    )
                } label: {
                    VeyraActionLabel(
                        title: "Afspelen",
                        symbol: "play.fill"
                    )
                }
                .buttonStyle(
                    VeyraFocusButtonStyle(
                        primary: true
                    )
                )

                Spacer()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding(
                .horizontal,
                VeyraSpacing.page
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
    }

    // MARK: - Media item

    private var mediaItem:
        MediaItem?
    {
        guard
            let imdbID,
            !imdbID.isEmpty
        else {
            return nil
        }

        return MediaItem(
            // BELANGRIJK:
            // Voor seriesources moet dit de
            // SERIETITEL zijn, niet de
            // afleveringstitel.
            title: series.name,

            type: .series,

            imdbID: imdbID,

            tmdbID:
                series.id,

            episodeTMDBID:
                episode.id,

            seasonNumber:
                episode.seasonNumber,

            episodeNumber:
                episode.episodeNumber,

            overview:
                episode.overview,

            releaseDate:
                episode.airDate,

            posterURL:
                imageURL(
                    path:
                        episode.stillPath,
                    size:
                        "w500"
                ),

            backdropURL:
                seriesBackdropURL
        )
    }

    // MARK: - Background

    @ViewBuilder
    private var background:
        some View
    {
        if
            let backdropURL =
                seriesBackdropURL
        {
            AsyncImage(
                url: backdropURL
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

    // MARK: - External IDs

    @MainActor
    private func loadExternalIDs()
        async
    {
        isLoading = true
        errorMessage = nil

        guard
            let service =
                SeriesService()
        else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."

            isLoading = false
            return
        }

        do {
            let externalIDs =
                try await service
                    .externalIDs(
                        forSeriesID:
                            series.id
                    )

            try Task
                .checkCancellation()

            guard
                let imdbID =
                    externalIDs.imdbID,
                !imdbID.isEmpty
            else {
                errorMessage =
                    "Voor deze serie is geen IMDb-ID beschikbaar."

                isLoading = false
                return
            }

            self.imdbID =
                imdbID

        } catch is CancellationError {
            return

        } catch {
            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        EpisodeView(
            series:
                TMDBSeriesDetails(
                    id: 1399,
                    name:
                        "Game of Thrones",
                    overview:
                        "Voorbeeldserie.",
                    posterPath: nil,
                    backdropPath: nil,
                    firstAirDate:
                        "2011-04-17",
                    voteAverage: 8.4,
                    numberOfSeasons: 8,
                    seasons: []
                ),
            episode:
                TMDBEpisode(
                    id: 1,
                    name:
                        "Winter Is Coming",
                    overview:
                        "Voorbeeldaflevering.",
                    episodeNumber: 1,
                    seasonNumber: 1,
                    stillPath: nil,
                    airDate:
                        "2011-04-17",
                    voteAverage: 8.0
                )
        )
    }
}
