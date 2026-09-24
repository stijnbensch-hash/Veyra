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

    // "Verder kijken"-voortgang per aflevering (Trakt playback-status),
    // zodat een aflevering die al gedeeltelijk bekeken is een balkje
    // krijgt, net als de "Verder kijken"-rij op Home.
    @ObservedObject private var traktStore = TraktStore.shared

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
                .veyraReadableWidth(860)
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
        NavigationLink {
            destination(for: episode)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack(alignment: .bottom) {
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

                    if let progress = watchProgress(for: episode) {
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(VeyraColors.cyan)
                                .frame(width: geometry.size.width * progress / 100, height: 3)
                        }
                        .frame(height: 3)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                    }
                }
                .frame(width: 140, height: 79)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if isEpisodeWatched(episode) {
                        watchedBadge
                            .padding(5)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Aflevering \(episode.episodeNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if watchProgress(for: episode) != nil {
                            Text("· Verder kijken")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VeyraColors.cyan)
                        }
                    }

                    Text(episode.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    if let airDate = episode.formattedAirDate {
                        Text(airDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func destination(for episode: TMDBEpisode) -> some View {
        SourceSelectionView(item: mediaItem(for: episode))
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

    // MARK: - Bekeken

    /// Klein rond vinkje rechtsboven in het miniatuurkader — alleen een
    /// symbool, geen tekstballon, zodat de lijst overzichtelijk blijft.
    private var watchedBadge: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle().stroke(VeyraColors.cyan.opacity(0.95), lineWidth: 1.5)
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VeyraColors.cyan)
        }
        .frame(width: 22, height: 22)
        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
        .accessibilityLabel("Bekeken")
    }

    private func isEpisodeWatched(_ episode: TMDBEpisode) -> Bool {
        TraktWatchedStatus.resolve(
            .episode(show: TraktIDs(tmdb: series.id), season: episode.seasonNumber, number: episode.episodeNumber),
            movies: traktStore.watchedMovies,
            shows: traktStore.watchedShows,
            progress: traktStore.upNext
        ) == .watched
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

    // MARK: - Media item

    // Geen `guard` meer op een aanwezige IMDb-ID: TMDB heeft die niet voor
    // elke (vooral regionale/Belgische) serie geregistreerd, en zonder deze
    // waarde werd de hele bronnenkiezer overgeslagen — ook IPTV- en
    // mediaserver-bronnen, die geen IMDb-ID nodig hebben. `imdbID` mag hier
    // dus gewoon `nil` zijn; addon-bronnen die er wél een nodig hebben
    // leveren dan simpelweg niets op, andere bronnen werken gewoon door.
    private func mediaItem(for episode: TMDBEpisode) -> MediaItem {
        MediaItem(
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
