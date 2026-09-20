import SwiftUI

/// "Verder kijken" op de iOS Home-tab: dezelfde Trakt-gegevens als tvOS
/// (gepauzeerde titels + volgende aflevering), maar met een eenvoudige,
/// native iOS-rij in plaats van de focus-gestuurde tvOS-kaarten.
struct ContinueWatchingRow: View {
    @ObservedObject private var store = TraktStore.shared
    @AppStorage(GeneralSettingsDefaults.showContinueWatchingKey) private var showContinueWatching = true
    @AppStorage(GeneralSettingsDefaults.continueWatchingLimitKey) private var continueWatchingLimit = 10
    @State private var destination: ContinueWatchingTarget?

    private var items: [TraktEntry] {
        var seen = Set<String>()
        var result: [TraktEntry] = []

        for entry in store.playback + store.cachedUpNextEntries {
            let key = identityKey(for: entry)
            if seen.insert(key).inserted {
                result.append(entry)
            }
        }

        return Array(result.prefix(max(0, continueWatchingLimit)))
    }

    var body: some View {
        Group {
            if showContinueWatching && store.isConnected && !items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    VeyraSectionHeader(title: "Verder kijken")
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(items, id: \.rowID) { entry in
                                Button {
                                    open(entry)
                                } label: {
                                    ContinueWatchingCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationDestination(item: $destination) { target in
            switch target {
            case .movie(let item):
                MovieDetailView(movie: item)
            case .series(let series):
                SeriesDetailView(series: series)
            }
        }
    }

    private func identityKey(for entry: TraktEntry) -> String {
        let kind = entry.movie != nil ? "movie" : "show"
        let media = entry.movie ?? entry.show

        if let tmdb = media?.ids.tmdb, tmdb > 0 {
            return "\(kind):tmdb:\(tmdb)"
        }
        if let imdb = media?.ids.imdb, !imdb.isEmpty {
            return "\(kind):imdb:\(imdb)"
        }
        return "\(kind):row:\(entry.rowID)"
    }

    private func open(_ entry: TraktEntry) {
        Task {
            if let movie = entry.movie, let tmdbID = movie.ids.tmdb, tmdbID > 0 {
                guard let service = TMDBService() else { return }
                if let item = try? await service.mediaItem(forMovieID: tmdbID) {
                    destination = .movie(item)
                }
            } else if let show = entry.show, let tmdbID = show.ids.tmdb, tmdbID > 0 {
                destination = .series(
                    TMDBSeries(
                        id: tmdbID,
                        name: show.title ?? entry.title,
                        overview: nil,
                        posterPath: nil,
                        backdropPath: nil,
                        firstAirDate: nil,
                        voteAverage: nil
                    )
                )
            }
        }
    }
}

private enum ContinueWatchingTarget: Hashable, Identifiable {
    case movie(MediaItem)
    case series(TMDBSeries)

    var id: String {
        switch self {
        case .movie(let item): return "movie:\(item.id)"
        case .series(let series): return "series:\(series.id)"
        }
    }
}

/// Eén kaart in de "Verder kijken"-rij. Haalt zijn eigen poster/titel op
/// zodat de rij zelf geen zware detail-fetch per item hoeft te doen.
private struct ContinueWatchingCard: View {
    let entry: TraktEntry

    @State private var title: String = ""
    @State private var posterURL: URL?

    private var progress: Double? {
        guard let value = entry.progress, value.isFinite, value > 0, value < 100 else {
            return nil
        }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottom) {
                AsyncImage(url: posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        ZStack {
                            VeyraColors.surface
                            Image(systemName: entry.movie != nil ? "film" : "tv")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 150, height: 225)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if let progress {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(VeyraColors.cyan)
                            .frame(width: geometry.size.width * progress / 100, height: 4)
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
            }

            Text(title.isEmpty ? entry.title : title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .frame(width: 150, alignment: .leading)
                .foregroundStyle(.primary)
        }
        .task {
            await loadArtwork()
        }
    }

    @MainActor
    private func loadArtwork() async {
        title = entry.title

        do {
            if let movie = entry.movie, let tmdbID = movie.ids.tmdb, tmdbID > 0,
               let service = TMDBService() {
                let item = try await service.mediaItem(forMovieID: tmdbID)
                title = item.title
                posterURL = item.posterURL

            } else if let show = entry.show, let tmdbID = show.ids.tmdb, tmdbID > 0,
                      let service = SeriesService() {
                let details = try await service.seriesDetails(id: tmdbID)
                title = entry.episode != nil ? entry.title : details.name
                if let path = details.posterPath, !path.isEmpty {
                    posterURL = URL(string: "https://image.tmdb.org/t/p/w500\(path)")
                }
            }
        } catch {
            // Kaart valt terug op de titel uit de Trakt-data zelf.
        }
    }
}
