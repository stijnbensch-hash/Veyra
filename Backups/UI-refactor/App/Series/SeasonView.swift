import SwiftUI

struct SeasonView: View {
    let series: TMDBSeriesDetails
    let season: TMDBSeason

    @State private var details: TMDBSeasonDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let imageBaseURL = URL(
        string: "https://image.tmdb.org/t/p/"
    )!

    var body: some View {
        ZStack {
            baseBackground
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Afleveringen laden…")
                    .font(.system(size: 28))
            } else if let errorMessage {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Afleveringen konden niet worden geladen")
                        .font(.system(size: 28))

                    Text(errorMessage)
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            } else if let details {
                episodeContent(details)
            }
        }
        .navigationTitle(season.name)
        .task {
            await loadSeason()
        }
    }

    @ViewBuilder
    private func episodeContent(
        _ details: TMDBSeasonDetails
    ) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .top, spacing: 40) {
                    seasonPoster(details)

                    VStack(alignment: .leading, spacing: 14) {
                        Text(series.name)
                            .font(
                                .system(
                                    size: 44,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.white)

                        Text(season.name)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(
                                .cyan.opacity(0.85)
                            )

                        if let overview = details.overview,
                           !overview.isEmpty {
                            Text(overview)
                                .font(.system(size: 22))
                                .foregroundStyle(
                                    .white.opacity(0.72)
                                )
                                .lineSpacing(4)
                                .lineLimit(6)
                        }
                    }

                    Spacer()
                }

                Text("AFLEVERINGEN")
                    .font(.system(size: 18))
                    .tracking(3)
                    .foregroundStyle(
                        .cyan.opacity(0.75)
                    )

                LazyVStack(spacing: 18) {
                    ForEach(
                        details.episodes.sorted {
                            $0.episodeNumber <
                            $1.episodeNumber
                        }
                    ) { episode in
                        NavigationLink {
                            EpisodeView(
                                series: series,
                                episode: episode
                            )
                        } label: {
                            episodeRow(episode)
                        }
                        .buttonStyle(.card)
                    }
                }
            }
            .padding(.horizontal, 70)
            .padding(.vertical, 45)
        }
    }

    @ViewBuilder
    private func episodeRow(
        _ episode: TMDBEpisode
    ) -> some View {
        HStack(spacing: 25) {
            AsyncImage(
                url: imageURL(
                    path: episode.stillPath,
                    size: "w500"
                )
            ) { phase in
                switch phase {
                case .empty:
                    episodePlaceholder
                        .overlay {
                            ProgressView()
                        }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    episodePlaceholder

                @unknown default:
                    episodePlaceholder
                }
            }
            .frame(
                width: 260,
                height: 146
            )
            .clipped()
            .clipShape(
                RoundedRectangle(cornerRadius: 14)
            )

            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                Text(
                    "\(episode.episodeNumber). \(episode.name)"
                )
                .font(.system(size: 28))
                .fontWeight(.semibold)
                .foregroundStyle(.white)

                if let overview = episode.overview,
                   !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 23))
                        .foregroundStyle(
                            .white.opacity(0.65)
                        )
                        .lineLimit(3)
                        .lineSpacing(3)
                }

                if let airDate = episode.airDate,
                   airDate.count >= 4 {
                    Text(String(airDate.prefix(4)))
                        .font(.system(size: 18))
                        .foregroundStyle(
                            .white.opacity(0.45)
                        )
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.45)
                )
        }
        .padding(18)
        .frame(
            maxWidth: 1200,
            alignment: .leading
        )
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.black.opacity(0.28))
        )
    }

    @ViewBuilder
    private func seasonPoster(
        _ details: TMDBSeasonDetails
    ) -> some View {
        AsyncImage(
            url: imageURL(
                path: details.posterPath,
                size: "w500"
            )
        ) { phase in
            switch phase {
            case .empty:
                posterPlaceholder
                    .overlay {
                        ProgressView()
                    }

            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()

            case .failure:
                posterPlaceholder

            @unknown default:
                posterPlaceholder
            }
        }
        .frame(
            width: 220,
            height: 330
        )
        .clipped()
        .clipShape(
            RoundedRectangle(cornerRadius: 18)
        )
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.white.opacity(0.08)

            Image(systemName: "tv")
                .font(.system(size: 84))
                .foregroundStyle(
                    .white.opacity(0.4)
                )
        }
    }

    private var episodePlaceholder: some View {
        ZStack {
            Color.white.opacity(0.08)

            Image(systemName: "play.rectangle")
                .font(.system(size: 54))
                .foregroundStyle(
                    .white.opacity(0.35)
                )
        }
    }

    private var baseBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.01, green: 0.04, blue: 0.07),
                Color(red: 0.02, green: 0.10, blue: 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
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
            .appendingPathComponent(size)
            .appendingPathComponent(
                path.trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "/"
                    )
                )
            )
    }

    @MainActor
    private func loadSeason() async {
        isLoading = true
        errorMessage = nil

        guard let service = SeriesService() else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }

        do {
            details = try await service.season(
                seriesID: series.id,
                seasonNumber: season.seasonNumber
            )
        } catch {
            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SeasonView(
            series: TMDBSeriesDetails(
                id: 1399,
                name: "Game of Thrones",
                overview: "Voorbeeldserie.",
                posterPath: nil,
                backdropPath: nil,
                firstAirDate: "2011-04-17",
                voteAverage: 8.4,
                numberOfSeasons: 8,
                seasons: []
            ),
            season: TMDBSeason(
                id: 3627,
                name: "Seizoen 1",
                overview: nil,
                seasonNumber: 1,
                posterPath: nil,
                episodeCount: 10
            )
        )
    }
}
