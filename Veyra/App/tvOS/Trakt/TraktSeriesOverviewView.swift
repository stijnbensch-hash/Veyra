import SwiftUI

/// Continue watching opens the whole show, while keeping the original episode route for resume.
struct TraktSeriesOverviewView: View {
    let entry: TraktEntry
    @State private var details: TMDBSeriesDetails?
    @State private var selectedSeason: Int?
    @State private var episodes: [TMDBEpisode] = []
    @State private var cachedSeasons: [Int: [TMDBEpisode]] = [:]
    @State private var loadingEpisodes = false
    @State private var error: String?
    @State private var episodeError: String?
    @State private var retry = 0

    var body: some View {
        ZStack {
            VeyraArtworkBackground(url: details?.backdropPath.flatMap {
                URL(string: "https://image.tmdb.org/t/p/w1280" + $0)
            })
            if let details {
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        VeyraHero(title: details.name, eyebrow: "Verder kijken",
                                  overview: details.overview) {
                            if let current = entry.episode,
                               let season = current.season, let number = current.number {
                                NavigationLink {
                                    TraktDestinationView(entry: entry)
                                } label: {
                                    VeyraActionLabel(title: "\(hasProgress ? "Hervatten" : "Bekijken") · S\(season) E\(number)", symbol: "play.fill")
                                }.buttonStyle(VeyraFocusButtonStyle(primary: true))
                            }
                        }
                        Text("Seizoenen").font(VeyraTypography.section)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 20) {
                                ForEach(details.seasons.sorted { $0.seasonNumber < $1.seasonNumber }) { season in
                                    Button { selectedSeason = season.seasonNumber } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(season.name)
                                                if selectedSeason == season.seasonNumber { Image(systemName: "checkmark") }
                                            }
                                            VeyraWatchedBadge(target: .season(show: TraktIDs(tmdb: details.id), number: season.seasonNumber, episodeCount: season.episodeCount))
                                            Text("\(season.episodeCount) afleveringen")
                                                .font(.system(size: 18)).foregroundStyle(.secondary)
                                        }.padding(20)
                                    }.buttonStyle(VeyraFocusButtonStyle())
                                }
                            }.padding(10)
                        }
                        Text("Afleveringen").font(VeyraTypography.section)
                        if loadingEpisodes {
                            ProgressView("Afleveringen laden…")
                        } else if let episodeError {
                            Text(episodeError).foregroundStyle(.secondary)
                            Button("Opnieuw proberen") { retry += 1 }
                        } else if episodes.isEmpty {
                            Text("Geen afleveringen beschikbaar in dit seizoen.").foregroundStyle(.secondary)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 350), spacing: 28)], spacing: 30) {
                                ForEach(episodes.sorted { $0.episodeNumber < $1.episodeNumber }) { episode in
                                    NavigationLink {
                                        EpisodeView(series: details, episode: episode)
                                    } label: {
                                        episodeCard(episode)
                                            .traktWatched(.episode(show: TraktIDs(tmdb: details.id), season: episode.seasonNumber, number: episode.episodeNumber))
                                    }.buttonStyle(VeyraFocusButtonStyle())
                                }
                            }
                        }
                    }.padding(60)
                }
            } else if let error {
                VStack(spacing: 24) {
                    Text(error)
                    Button("Opnieuw proberen") { retry += 1 }
                }.padding(60)
            } else { ProgressView("Serie laden…") }
        }
        .task(id: retry) {
            if details == nil { await loadShow() }
            else { await loadSeason() }
        }
        .task(id: selectedSeason) { await loadSeason() }
    }

    private var hasProgress: Bool {
        guard let progress = entry.progress else { return false }
        return progress.isFinite && progress > 0 && progress < 100
    }
    private func episodeCard(_ episode: TMDBEpisode) -> some View {
        let current = entry.episode?.season == episode.seasonNumber && entry.episode?.number == episode.episodeNumber
        return VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: episode.stillPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500" + $0) }) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack { VeyraColors.surface; Image(systemName: "play.tv").font(.system(size: 40)) }
            }
            .frame(height: 195).frame(maxWidth: .infinity).clipped()
            .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.poster))
            Text("E\(episode.episodeNumber) · \(episode.name)")
                .font(.system(size: 23, weight: .semibold)).lineLimit(2).frame(height: 58, alignment: .topLeading)
            Text(current ? (hasProgress ? "Verder kijken" : "Volgende aflevering") : "Aflevering bekijken")
                .font(.system(size: 19)).foregroundStyle(current ? VeyraColors.cyan : VeyraColors.secondary)
            if current, hasProgress, let progress = entry.progress {
                ProgressView(value: progress, total: 100).tint(VeyraColors.red)
            }
        }.padding(12)
    }
    private func loadShow() async {
        error = nil
        guard let id = entry.show?.ids.tmdb, let service = SeriesService() else {
            error = "Geen seriegegevens beschikbaar. Controleer de TMDB-instellingen."
            return
        }
        do {
            let value = try await service.seriesDetails(id: id)
            try Task.checkCancellation()
            details = value
            let current = entry.episode?.season
            selectedSeason = value.seasons.first(where: { $0.seasonNumber == current })?.seasonNumber
                ?? value.seasons.filter { $0.seasonNumber > 0 }.map(\.seasonNumber).min()
                ?? value.seasons.first?.seasonNumber
        } catch is CancellationError {} catch { self.error = "Serie kon niet worden geladen. Probeer opnieuw." }
    }
    private func loadSeason() async {
        guard let details, let number = selectedSeason, let service = SeriesService() else { return }
        episodeError = nil
        episodes = []
        if let cached = cachedSeasons[number] { episodes = cached; loadingEpisodes = false; return }
        loadingEpisodes = true
        do {
            let value = try await service.season(seriesID: details.id, seasonNumber: number)
            try Task.checkCancellation()
            guard selectedSeason == number else { return }
            cachedSeasons[number] = value.episodes
            episodes = value.episodes
            loadingEpisodes = false
        } catch is CancellationError {} catch {
            guard selectedSeason == number else { return }
            loadingEpisodes = false
            episodeError = "Afleveringen konden niet worden geladen. Probeer opnieuw."
        }
    }
}
