import SwiftUI

struct SeriesDetailView: View {
    let series: TMDBSeries

    @StateObject private var viewModel: SeriesDetailViewModel
    @State private var ratings = MetadataRatings()

    init(series: TMDBSeries) {
        self.series = series
        _viewModel = StateObject(wrappedValue: SeriesDetailViewModel(seriesID: series.id))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                backdrop

                VStack(alignment: .leading, spacing: 14) {
                    if viewModel.isLoading {
                        ProgressView("Serie laden…")
                    } else if let errorMessage = viewModel.errorMessage {
                        Text("Serie kon niet worden geladen")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if let details = viewModel.details {
                        Text(details.name)
                            .font(.title.weight(.bold))

                        if let year = releaseYear(from: details.firstAirDate) {
                            Text(year)
                                .font(.subheadline)
                                .foregroundStyle(VeyraColors.cyan)
                        }

                        MetadataRatingsView(ratings: ratings)

                        if !details.overview.isEmpty {
                            Text(details.overview)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        WatchlistToggleButton(item: mediaItem(from: details))

                        let seasons = details.seasons.filter { $0.seasonNumber > 0 }
                        if !seasons.isEmpty {
                            Text("Seizoenen")
                                .font(.headline)
                                .padding(.top, 8)

                            ForEach(seasons) { season in
                                NavigationLink {
                                    SeasonEpisodesView(series: details, season: season)
                                } label: {
                                    HStack {
                                        Text("Seizoen \(season.seasonNumber)")
                                        Spacer()
                                        Text("\(season.episodeCount) afl.")
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        .background(VeyraColors.background.ignoresSafeArea())
        .navigationTitle(series.name)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .task { await viewModel.loadDetails() }
        .task(id: series.id) {
            ratings = await MetadataRatingsService.seriesRatings(tmdbID: series.id, imdbID: nil)
        }
    }

    private var backdrop: some View {
        AsyncImage(url: imageURL(path: viewModel.details?.backdropPath ?? series.backdropPath, size: "w1280")) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                VeyraColors.surface
            }
        }
        .frame(height: 220)
        .clipped()
    }

    private func imageURL(path: String?, size: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }

    private func releaseYear(from date: String?) -> String? {
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    /// `MediaItem` voor de serie als geheel (geen seizoen/aflevering), voor
    /// de watchlist-knop op deze infopagina.
    private func mediaItem(from details: TMDBSeriesDetails) -> MediaItem {
        MediaItem(
            title: details.name,
            type: .series,
            tmdbID: series.id,
            overview: details.overview,
            releaseDate: details.firstAirDate,
            backdropURL: imageURL(path: details.backdropPath ?? series.backdropPath, size: "w1280")
        )
    }
}
