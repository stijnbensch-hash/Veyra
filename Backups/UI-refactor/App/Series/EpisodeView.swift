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
                    Color(red: 0.01, green: 0.04, blue: 0.07)
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

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Aflevering laden…")
                .font(.system(size: 30))
        } else if let errorMessage {
            VStack(alignment: .leading, spacing: 16) {
                Text("Aflevering kon niet worden geladen")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)

                Text(errorMessage)
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
        } else if let imdbID {
            VStack(alignment: .leading, spacing: 26) {
                Text(series.name)
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(.cyan.opacity(0.85))

                Text(episode.name)
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(
                    "Seizoen \(episode.seasonNumber) · Aflevering \(episode.episodeNumber)"
                )
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))

                if let overview = episode.overview,
                   !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineSpacing(7)
                        .lineLimit(7)
                        .frame(
                            maxWidth: 900,
                            alignment: .leading
                        )
                }

                NavigationLink {
                    SourceSelectionView(
                        item: MediaItem(
                            title: episode.name,
                            type: .series,
                            imdbID: imdbID,
                            tmdbID: series.id,
                            episodeTMDBID: episode.id,
                            seasonNumber: episode.seasonNumber,
                            episodeNumber: episode.episodeNumber,
                            overview: episode.overview,
                            releaseDate: episode.airDate,
                            posterURL: imageURL(
                                path: episode.stillPath,
                                size: "w500"
                            ),
                            backdropURL: seriesBackdropURL
                        )
                    )
                } label: {
                    Label(
                        "AFSPELEN",
                        systemImage: "play.fill"
                    )
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)

                TraktActionsView(item: MediaItem(
                    title: episode.name, type: .series, imdbID: imdbID,
                    tmdbID: series.id, episodeTMDBID: episode.id,
                    seasonNumber: episode.seasonNumber, episodeNumber: episode.episodeNumber
                ))

                Spacer()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding(.horizontal, 70)
            .padding(.vertical, 60)
        }
    }

    @ViewBuilder
    private var background: some View {
        if let backdropURL = seriesBackdropURL {
            AsyncImage(url: backdropURL) { phase in
                switch phase {
                case .empty:
                    baseBackground

                case .success(let image):
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

    private var baseBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.01, green: 0.04, blue: 0.07),
                Color(red: 0.02, green: 0.10, blue: 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var seriesBackdropURL: URL? {
        imageURL(
            path: series.backdropPath,
            size: "w1280"
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
                    in: CharacterSet(charactersIn: "/")
                )
            )
    }

    @MainActor
    private func loadExternalIDs() async {
        isLoading = true
        errorMessage = nil

        guard let service = SeriesService() else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }

        do {
            let externalIDs = try await service.externalIDs(
                forSeriesID: series.id
            )

            guard
                let imdbID = externalIDs.imdbID,
                !imdbID.isEmpty
            else {
                errorMessage =
                    "Voor deze serie is geen IMDb-ID beschikbaar."
                isLoading = false
                return
            }

            self.imdbID = imdbID
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        EpisodeView(
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
            episode: TMDBEpisode(
                id: 1,
                name: "Winter Is Coming",
                overview: "Voorbeeldaflevering.",
                episodeNumber: 1,
                seasonNumber: 1,
                stillPath: nil,
                airDate: "2011-04-17",
                voteAverage: 8.0
            )
        )
    }
}
