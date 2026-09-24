import SwiftUI

/// Toont de seizoenen/afleveringen van een IPTV-serie (Xtream Codes) die als
/// los item aan een plank is toegevoegd (`ShelfSource.iptv`, kind `.series`)
/// — anders dan een film heeft een serie geen eigen afspeel-URL, dus wordt
/// hier eerst de aflevering gekozen via de provider's `get_series_info`.
/// Werkt op tvOS en iOS.
struct ShelfIPTVSeriesEpisodesView: View {
    let seriesID: Int
    let providerName: String
    let title: String
    let posterURL: URL?

    @State private var seasons: [(season: Int, episodes: [XtreamSeriesEpisode])] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let configurationStore = IPTVConfigurationStore()
    private let service = IPTVService()

    var body: some View {
        List {
            if isLoading {
                ProgressView("Afleveringen laden…")
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.secondary)
            } else if seasons.isEmpty {
                Text("Geen afleveringen gevonden voor deze serie.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(seasons, id: \.season) { entry in
                    Section("Seizoen \(entry.season)") {
                        ForEach(entry.episodes) { episode in
                            episodeRow(episode)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .task { await load() }
    }

    // MARK: - Rij

    private func episodeRow(_ episode: XtreamSeriesEpisode) -> some View {
        NavigationLink {
            PlayerView(
                source: PlayableSource(
                    name: "\(title) · S\(episode.seasonNumber)E\(episode.episodeNumber)",
                    description: episode.title,
                    url: episode.streamURL,
                    kind: .iptvVOD,
                    providerName: providerName
                )
            )
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Aflevering \(episode.episodeNumber)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)

                if !episode.title.isEmpty, episode.title != "Aflevering \(episode.episodeNumber)" {
                    Text(episode.title)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Laden

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard
                let provider = try configurationStore.loadProviders()
                    .first(where: { $0.displayName == providerName }),
                case .xtream(let xtream) = provider.configuration
            else {
                errorMessage = "De provider van deze serie is niet meer beschikbaar."
                return
            }

            let info = try await service.loadXtreamSeriesInfo(configuration: xtream, seriesID: seriesID)
            let grouped = Dictionary(grouping: info.episodes) { $0.seasonNumber }
            seasons = grouped
                .map { (season: $0.key, episodes: $0.value.sorted { $0.episodeNumber < $1.episodeNumber }) }
                .sorted { $0.season < $1.season }
        } catch {
            errorMessage = "Afleveringen konden niet worden geladen: \(error.localizedDescription)"
        }
    }
}
