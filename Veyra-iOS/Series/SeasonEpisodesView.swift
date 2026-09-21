import SwiftUI

/// Toont de afleveringen van één seizoen op iOS en laat de gebruiker een
/// aflevering openen om af te spelen (via de gedeelde bronnenkiezer).
struct SeasonEpisodesView: View {
    let series: TMDBSeriesDetails
    let season: TMDBSeason

    @State private var episodes: [TMDBEpisode] = []
    @State private var imdbID: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let imageBaseURL = URL(string: "https://image.tmdb.org/t/p/w500")!

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            Group {
            if isLoading {
                ProgressView("Afleveringen laden…")
            } else if let errorMessage {
                errorView(errorMessage)
            } else if episodes.isEmpty {
                ContentUnavailableView(
                    "Geen afleveringen gevonden",
                    systemImage: "tv"
                )
            } else {
                List(episodes.sorted { $0.episodeNumber < $1.episodeNumber }) { episode in
                    episodeRow(episode)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            }
        }
        .navigationTitle(season.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSeason()
        }
    }

    // MARK: - Episode row

    private func episodeRow(_ episode: TMDBEpisode) -> some View {
        ZStack {
            NavigationLink {
                destination(for: episode)
            } label: {
                EmptyView()
            }
            .opacity(0)

            HStack(alignment: .top, spacing: 14) {
                AsyncImage(url: imageURL(path: episode.stillPath)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        ZStack {
                            VeyraColors.surface
                            Image(systemName: "tv")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 140, height: 79)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Aflevering \(episode.episodeNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(episode.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                // Bladwijzersymbool om deze aflevering toe te voegen aan of
                // te verwijderen uit de Trakt-watchlist, los van de
                // NavigationLink hierboven zodat een tik erop niet ook de
                // afleveringspagina opent.
                if let mediaItem = mediaItem(for: episode) {
                    WatchlistToggleButton(item: mediaItem, compact: true)
                        .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private func destination(for episode: TMDBEpisode) -> some View {
        if let mediaItem = mediaItem(for: episode) {
            SourceSelectionView(item: mediaItem)
        } else {
            ContentUnavailableView(
                "Deze aflevering kan niet worden afgespeeld",
                systemImage: "exclamationmark.triangle",
                description: Text(
                    "Voor deze serie is geen IMDb-ID beschikbaar."
                )
            )
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("Afleveringen konden niet worden geladen")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Opnieuw proberen") {
                Task { await loadSeason() }
            }
        }
        .padding()
    }

    // MARK: - Media item

    private func mediaItem(for episode: TMDBEpisode) -> MediaItem? {
        guard let imdbID, !imdbID.isEmpty else {
            return nil
        }

        return MediaItem(
            // Voor seriebronnen moet dit de serietitel zijn,
            // niet de afleveringstitel.
            title: series.name,
            type: .series,
            imdbID: imdbID,
            tmdbID: series.id,
            episodeTMDBID: episode.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
            overview: episode.overview,
            releaseDate: episode.airDate,
            posterURL: imageURL(path: episode.stillPath),
            backdropURL: imageURL(path: series.backdropPath, size: "w1280")
        )
    }

    private func imageURL(path: String?, size: String = "w500") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }

    // MARK: - Load

    @MainActor
    private func loadSeason() async {
        isLoading = true
        errorMessage = nil

        guard let service = SeriesService() else {
            errorMessage = "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }

        do {
            async let seasonDetails = service.season(
                seriesID: series.id,
                seasonNumber: season.seasonNumber
            )

            async let externalIDs = service.externalIDs(
                forSeriesID: series.id
            )

            let (season, ids) = try await (seasonDetails, externalIDs)

            episodes = season.episodes
            imdbID = ids.imdbID

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
