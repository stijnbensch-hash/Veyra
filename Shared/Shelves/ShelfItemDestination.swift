import SwiftUI

/// Opent een plank-item (uit Trakt/TMDB/een addon-catalogus) in de bestaande
/// detailschermen. Films gaan direct door (die schermen werken al met
/// `MediaItem`); series worden eerst naar een volledige `TMDBSeries`
/// opgelost, net als bij Trakt's "Verder kijken".
struct ShelfItemDestination: View {
    let item: MediaItem

    @State private var resolvedSeries: TMDBSeries?
    @State private var errorMessage: String?
    @State private var loading = true

    var body: some View {
        Group {
            if item.type == .movie {
                MovieDetailView(movie: item)
            } else if item.type == .liveTV, let streamURL = item.streamURL {
                PlayerView(
                    source: PlayableSource(
                        name: item.title,
                        description: item.overview,
                        url: streamURL,
                        kind: .liveTV,
                        providerName: "IPTV"
                    ),
                    item: item
                )
            } else if let resolvedSeries {
                SeriesDetailView(series: resolvedSeries)
            } else if let errorMessage {
                VStack(spacing: 20) {
                    Text("Titel kon niet worden geopend")
                        .font(.system(size: 24, weight: .semibold))
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Opnieuw proberen") { Task { await resolveSeries() } }
                }
                .padding()
                .frame(maxWidth: 600)
            } else if loading {
                ProgressView("Titel openen…")
            }
        }
        .task { await resolveSeries() }
    }

    private func resolveSeries() async {
        guard item.type == .series else { return }
        loading = true
        errorMessage = nil
        defer { loading = false }

        guard let tmdbID = item.tmdbID, let service = SeriesService() else {
            errorMessage = "Deze titel kon niet in TMDB gevonden worden."
            return
        }

        do {
            let details = try await service.seriesDetails(id: tmdbID)
            resolvedSeries = TMDBSeries(
                id: tmdbID,
                name: details.name,
                overview: details.overview,
                posterPath: details.posterPath,
                backdropPath: details.backdropPath,
                firstAirDate: details.firstAirDate,
                voteAverage: details.voteAverage,
                genreIDs: nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
