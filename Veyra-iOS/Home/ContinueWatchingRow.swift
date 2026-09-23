import SwiftUI

/// "Verder kijken" op de iOS Home-tab: dezelfde Trakt-gegevens als tvOS
/// (gepauzeerde titels + volgende aflevering), nu ook in hetzelfde
/// landscape-kaartformaat als tvOS (`TraktContinueWatchingView`): een
/// achtergrondafbeelding (TMDB-backdrop) met de afleveringscode linksonder
/// en het aantal resterende afleveringen rechtsonder, en daaronder een
/// vetgedrukte titel met een lichtere ondertitel.
struct ContinueWatchingRow: View {
    @ObservedObject private var store = TraktStore.shared
    @AppStorage(GeneralSettingsDefaults.showContinueWatchingKey) private var showContinueWatching = true
    @AppStorage(GeneralSettingsDefaults.continueWatchingLimitKey) private var continueWatchingLimit = 10
    @State private var destination: ContinueWatchingTarget?

    // "Details overslaan bij verdergaan" (Afspelen-instellingen): films
    // gaan dan direct naar bronkeuze in plaats van eerst het filmdetail te
    // tonen. Voor series blijft dit via het detailscherm lopen — daar moet
    // sowieso een aflevering gekozen worden.
    @AppStorage(PlaybackSettingsDefaults.skipContinueWatchingDetailsKey)
    private var skipContinueWatchingDetails = false

    private var items: [ContinueWatchingItemIOS] {
        var seen = Set<String>()
        var result: [ContinueWatchingItemIOS] = []

        let paused = store.playback.map {
            ContinueWatchingItemIOS(entry: $0, isNextEpisode: false, episodeProgress: episodeProgress(for: $0))
        }
        let next = store.cachedUpNextEntries.map {
            ContinueWatchingItemIOS(entry: $0, isNextEpisode: true, episodeProgress: episodeProgress(for: $0))
        }

        for item in paused + next {
            let key = identityKey(for: item.entry)
            if seen.insert(key).inserted {
                result.append(item)
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
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(items) { item in
                                Button {
                                    open(item.entry)
                                } label: {
                                    ContinueWatchingCardIOS(item: item)
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
            case .moviePlayback(let item):
                SourceSelectionView(item: item)
            case .series(let series):
                SeriesDetailView(series: series)
            }
        }
        .onChange(of: destination) { _, newValue in
            // Meldt deze push aan bij de gedeelde Home-navigatiestatus zodat
            // de zwevende zoek-/instellingenknoppen verdwijnen zolang een
            // titel vanuit "Verder kijken" geopend staat.
            HomeNavigationState.shared.setActive(newValue != nil, source: "continueWatching")
        }
        // Ververst zelf, net als tvOS's TraktContinueWatchingView — anders
        // toont deze rij alleen wat een ander tabblad (Instellingen, Films,
        // Series) toevallig al heeft opgehaald of wat nog in de lokale
        // cache staat.
        .task(id: store.isConnected) {
            guard store.isConnected else { return }
            await store.refreshIfNeeded()
        }
    }

    // MARK: - Afleveringsvoortgang (aantal resterende afleveringen)

    private func episodeProgress(for entry: TraktEntry) -> TraktShowProgress? {
        guard let show = entry.show else { return nil }
        return store.upNext.first { $0.show.ids.matches(show.ids) }?.progress
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
                    destination = skipContinueWatchingDetails ? .moviePlayback(item) : .movie(item)
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
                        voteAverage: nil,
                        genreIDs: nil
                    )
                )
            }
        }
    }
}

private enum ContinueWatchingTarget: Hashable, Identifiable {
    case movie(MediaItem)
    case moviePlayback(MediaItem)
    case series(TMDBSeries)

    var id: String {
        switch self {
        case .movie(let item): return "movie:\(item.id)"
        case .moviePlayback(let item): return "moviePlayback:\(item.id)"
        case .series(let series): return "series:\(series.id)"
        }
    }
}

// MARK: - Item

private struct ContinueWatchingItemIOS: Identifiable {
    let entry: TraktEntry
    let isNextEpisode: Bool
    let episodeProgress: TraktShowProgress?

    var id: String { entry.rowID }

    var episodeCode: String? {
        guard let episode = entry.episode, let season = episode.season, let number = episode.number else {
            return nil
        }
        return String(format: "S%02dE%02d", season, number)
    }

    var remainingCount: Int? {
        guard let episodeProgress, episodeProgress.aired > 0 else { return nil }
        let remaining = episodeProgress.aired - episodeProgress.completed
        return remaining > 0 ? remaining : nil
    }

    var playbackProgress: Double? {
        guard !isNextEpisode, let progress = entry.progress, progress.isFinite, progress > 0, progress < 100 else {
            return nil
        }
        return progress
    }

    var displayTitle: String {
        if let movie = entry.movie { return movie.title ?? "Film" }
        if entry.episode != nil { return entry.show?.title ?? "Serie" }
        if let show = entry.show { return show.title ?? entry.title }
        return entry.title
    }

    var displaySubtitle: String? {
        guard let rawTitle = entry.episode?.title else { return nil }
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }
}

// MARK: - Kaart

private struct ContinueWatchingCardIOS: View {
    let item: ContinueWatchingItemIOS

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                TraktLandscapeArtworkIOS(entry: item.entry)
                    .frame(width: 260, height: 146)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.05), .black.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .allowsHitTesting(false)
                    }
                    .overlay(alignment: .bottomLeading) {
                        if let episodeCode = item.episodeCode {
                            VeyraPosterBadge(title: episodeCode, fontSize: 11)
                                .padding(8)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if let remainingCount = item.remainingCount {
                            VeyraPosterBadge(
                                title: "\(remainingCount) resterend",
                                accent: VeyraColors.cyan,
                                fontSize: 11
                            )
                            .padding(8)
                        }
                    }

                if let progress = item.playbackProgress {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(VeyraColors.cyan)
                            .frame(width: geometry.size.width * progress / 100, height: 3)
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }

            Text(item.displayTitle)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .foregroundStyle(.primary)
                .frame(width: 260, alignment: .leading)

            if let subtitle = item.displaySubtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 260, alignment: .leading)
            }
        }
    }
}

/// Haalt de TMDB-achtergrondafbeelding (backdrop) op voor een Trakt-item,
/// net als tvOS's `TraktLandscapePoster` — zo krijgt "Verder kijken" op
/// iOS dezelfde brede, landschap-georiënteerde artwork in plaats van een
/// uitgerekte portret-poster.
private struct TraktLandscapeArtworkIOS: View {
    let entry: TraktEntry

    @State private var backdropURL: URL?
    @State private var loading = true

    private var tmdbID: Int? {
        entry.movie?.ids.tmdb ?? entry.show?.ids.tmdb
    }

    private var endpoint: String { entry.movie != nil ? "movie" : "tv" }
    private var artworkKey: String { "\(endpoint):\(tmdbID ?? 0)" }

    var body: some View {
        ZStack {
            VeyraColors.surface

            if let backdropURL {
                AsyncImage(url: backdropURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        ProgressView()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else if loading {
                ProgressView()
            } else {
                placeholder
            }
        }
        .task(id: artworkKey) {
            await loadBackdrop()
        }
    }

    private var placeholder: some View {
        Image(systemName: entry.movie != nil ? "film" : "tv")
            .font(.system(size: 32))
            .foregroundStyle(.secondary)
    }

    @MainActor
    private func loadBackdrop() async {
        loading = true
        backdropURL = nil
        defer { loading = false }

        guard
            let tmdbID, tmdbID > 0,
            let token = AppConfiguration.tmdbReadAccessToken, !token.isEmpty,
            let url = URL(string: "https://api.themoviedb.org/3/\(endpoint)/\(tmdbID)?language=nl-NL")
        else {
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                !Task.isCancelled,
                let http = response as? HTTPURLResponse,
                (200..<300).contains(http.statusCode)
            else {
                return
            }

            let result = try JSONDecoder().decode(TMDBBackdropResponseIOS.self, from: data)
            let paths = [result.backdropPath, result.posterPath]
                .compactMap { $0 }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            guard
                let path = paths.first(where: { !$0.isEmpty }),
                let baseURL = URL(string: "https://image.tmdb.org/t/p/w780")
            else {
                return
            }

            backdropURL = baseURL.appendingPathComponent(
                path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            )
        } catch {
            // Artwork is optioneel.
        }
    }
}

private struct TMDBBackdropResponseIOS: Decodable {
    let backdropPath: String?
    let posterPath: String?

    enum CodingKeys: String, CodingKey {
        case backdropPath = "backdrop_path"
        case posterPath = "poster_path"
    }
}
