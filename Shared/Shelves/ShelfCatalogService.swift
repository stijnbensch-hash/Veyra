import Foundation

/// Haalt de items op voor een geconfigureerde plank (`Shelf`), ongeacht de
/// bron (Trakt, TMDB of een addon-catalogus zoals AIOMetadata), en levert ze
/// als uniforme `MediaItem`s af zodat elk platform ze op dezelfde manier kan
/// tonen en openen.
enum ShelfCatalogService {
    static func items(for shelf: Shelf) async -> [MediaItem] {
        switch shelf.source {
        case .trakt(let list, let kind):
            let raw = await traktItems(list: list, kind: kind)
            return await enrichWithArtwork(raw, kind: kind)

        case .tmdb(let list, let kind):
            return await tmdbItems(list: list, kind: kind)

        case .addon(let addonID, _, let catalogType, let catalogID, _):
            return await addonItems(addonID: addonID, catalogType: catalogType, catalogID: catalogID)

        case .iptv(let channels):
            return channels.map(mediaItem(from:))
        }
    }

    // MARK: - IPTV

    private static func mediaItem(from channel: ShelfIPTVChannel) -> MediaItem {
        if channel.kind == .series {
            return MediaItem(
                title: channel.name,
                type: .iptvSeries,
                overview: channel.group,
                posterURL: channel.logoURL,
                iptvSeriesID: Int(channel.channelID),
                iptvProviderName: channel.providerName
            )
        }

        return MediaItem(
            title: channel.name,
            type: .liveTV,
            overview: channel.group,
            posterURL: channel.logoURL,
            streamURL: channel.streamURL
        )
    }

    // MARK: - Trakt

    private static func traktItems(list: TraktShelfList, kind: ShelfMediaKind) async -> [MediaItem] {
        let segment = kind == .movie ? "movies" : "shows"
        let client = await TraktStore.shared.client

        do {
            let entries: [TraktEntry]
            if list.requiresAuthentication {
                guard await client.isAuthenticated else { return [] }
                switch list {
                case .personal(let id, _, _):
                    entries = try await client.request("users/me/lists/\(id)/items/\(segment)")
                default:
                    entries = try await client.request("sync/watchlist/\(segment)")
                }
            } else {
                entries = try await client.publicRequest("\(segment)/\(list.path)")
            }
            return entries.compactMap { mediaItem(from: $0, kind: kind) }
        } catch {
            return []
        }
    }

    /// De persoonlijke lijsten van de gekoppelde Trakt-gebruiker, om als
    /// plank-bron te kunnen kiezen naast de vaste lijsten hierboven.
    static func fetchTraktPersonalLists() async -> [TraktPersonalList] {
        let client = await TraktStore.shared.client
        guard await client.isAuthenticated else { return [] }
        do {
            return try await client.request("users/me/lists")
        } catch {
            return []
        }
    }

    private static func mediaItem(from entry: TraktEntry, kind: ShelfMediaKind) -> MediaItem? {
        guard let media = kind == .movie ? entry.movie : entry.show,
              let title = media.title
        else { return nil }

        return MediaItem(
            title: title,
            type: kind == .movie ? .movie : .series,
            imdbID: media.ids.imdb,
            tmdbID: media.ids.tmdb,
            overview: media.overview,
            releaseDate: media.year.map(String.init)
        )
    }

    // MARK: - Artwork-verrijking (voor bronnen zoals Trakt die zelf geen
    // afbeeldingen meeleveren) — via TMDB of, indien ingesteld, een
    // AIOMetadata-addon.

    private static func enrichWithArtwork(_ items: [MediaItem], kind: ShelfMediaKind) async -> [MediaItem] {
        guard !items.isEmpty else { return items }
        let addon = MetadataSourcePreference.activeAddon()

        return await withTaskGroup(of: (Int, MediaItem).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    (index, await enrich(item, kind: kind, addon: addon))
                }
            }

            var results = items
            for await (index, enriched) in group {
                results[index] = enriched
            }
            return results
        }
    }

    private static func enrich(_ item: MediaItem, kind: ShelfMediaKind, addon: AddonManifest?) async -> MediaItem {
        if let addon, let imdbID = item.imdbID, !imdbID.isEmpty {
            let client = AIOMetadataClient(baseURL: addon.baseURL)
            if let meta = try? await client.meta(type: kind == .movie ? "movie" : "series", imdbID: imdbID) {
                return MediaItem(
                    id: item.id,
                    title: item.title,
                    type: item.type,
                    imdbID: item.imdbID,
                    tmdbID: item.tmdbID,
                    overview: item.overview?.isEmpty == false ? item.overview : meta.description,
                    releaseDate: item.releaseDate,
                    posterURL: meta.posterURL ?? item.posterURL,
                    backdropURL: meta.backdropURL ?? item.backdropURL,
                    genre: item.genre,
                    rating: item.rating
                )
            }
        }

        guard let tmdbID = item.tmdbID else { return item }

        if kind == .movie, let token = AppConfiguration.tmdbReadAccessToken {
            if let details = try? await TMDBClient(readAccessToken: token).movieDetails(id: tmdbID) {
                return MediaItem(
                    id: item.id,
                    title: item.title,
                    type: item.type,
                    imdbID: item.imdbID,
                    tmdbID: item.tmdbID,
                    overview: item.overview,
                    releaseDate: item.releaseDate,
                    posterURL: imageURL(details.posterPath),
                    backdropURL: imageURL(details.backdropPath, size: "w1280"),
                    genre: item.genre,
                    rating: details.voteAverage ?? item.rating
                )
            }
        } else if kind == .series, let service = SeriesService() {
            if let details = try? await service.seriesDetails(id: tmdbID) {
                return MediaItem(
                    id: item.id,
                    title: item.title,
                    type: item.type,
                    imdbID: item.imdbID,
                    tmdbID: item.tmdbID,
                    overview: item.overview,
                    releaseDate: item.releaseDate,
                    posterURL: imageURL(details.posterPath),
                    backdropURL: imageURL(details.backdropPath, size: "w1280"),
                    genre: item.genre,
                    rating: details.voteAverage ?? item.rating
                )
            }
        }

        return item
    }

    private static func imageURL(_ path: String?, size: String = "w500") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }

    // MARK: - TMDB

    private static func tmdbItems(list: TMDBShelfList, kind: ShelfMediaKind) async -> [MediaItem] {
        guard let token = AppConfiguration.tmdbReadAccessToken else { return [] }

        if case .personal(let id, _) = list {
            do {
                let details = try await TMDBClient(readAccessToken: token).list(id: id)
                return details.results
                    .filter { $0.isMovie == (kind == .movie) }
                    .map { mediaItem(from: $0) }
            } catch { return [] }
        }

        if kind == .movie {
            let client = TMDBClient(readAccessToken: token)
            let movies: [TMDBMovie]
            do {
                switch list {
                case .popular: movies = try await client.popularMovies()
                case .topRated: movies = try await client.topRatedMovies()
                case .trendingDay: movies = try await client.trendingMovies(window: "day")
                case .trendingWeek: movies = try await client.trendingMovies(window: "week")
                case .nowPlayingOrOnTheAir: movies = try await client.nowPlayingMovies()
                case .upcoming: movies = try await client.upcomingMovies()
                case .personal: movies = []
                }
            } catch { return [] }
            return movies.map { mediaItem(from: $0) }
        } else {
            guard let service = SeriesService() else { return [] }
            let series: [TMDBSeries]
            do {
                switch list {
                case .popular: series = try await service.popularSeries()
                case .topRated: series = try await service.topRatedSeries()
                case .trendingDay: series = try await service.trendingSeries(window: "day")
                case .trendingWeek: series = try await service.trendingSeries(window: "week")
                case .nowPlayingOrOnTheAir: series = try await service.onTheAirSeries()
                case .upcoming: series = try await service.popularSeries()
                case .personal: series = []
                }
            } catch { return [] }
            return series.map { mediaItem(from: $0) }
        }
    }

    /// Haalt een publieke TMDB-lijst op via het lijst-ID, voor gebruik als
    /// eigen plank-lijst. Geeft ook de naam terug zodat de plank een goede
    /// standaardtitel kan krijgen.
    static func fetchTMDBPersonalList(id: Int) async throws -> (name: String, itemCount: Int) {
        guard let token = AppConfiguration.tmdbReadAccessToken else {
            throw TMDBError.invalidURL
        }
        let details = try await TMDBClient(readAccessToken: token).list(id: id)
        return (details.name ?? "TMDB-lijst \(id)", details.results.count)
    }

    private static func mediaItem(from item: TMDBListItem) -> MediaItem {
        MediaItem(
            title: item.displayTitle,
            type: item.isMovie ? .movie : .series,
            tmdbID: item.id,
            overview: item.overview,
            releaseDate: item.displayReleaseDate,
            posterURL: imageURL(item.posterPath),
            backdropURL: imageURL(item.backdropPath, size: "w1280")
        )
    }

    private static func mediaItem(from movie: TMDBMovie) -> MediaItem {
        MediaItem(
            title: movie.title,
            type: .movie,
            tmdbID: movie.id,
            overview: movie.overview,
            releaseDate: movie.releaseDate,
            posterURL: imageURL(movie.posterPath),
            backdropURL: imageURL(movie.backdropPath, size: "w1280"),
            genre: TMDBGenreNames.firstMovieName(for: movie.genreIDs ?? []),
            rating: movie.voteAverage
        )
    }

    private static func mediaItem(from series: TMDBSeries) -> MediaItem {
        MediaItem(
            title: series.name,
            type: .series,
            tmdbID: series.id,
            overview: series.overview,
            releaseDate: series.firstAirDate,
            posterURL: imageURL(series.posterPath),
            backdropURL: imageURL(series.backdropPath, size: "w1280"),
            genre: TMDBGenreNames.firstTVName(for: series.genreIDs ?? []),
            rating: series.voteAverage
        )
    }

    // MARK: - Addon-catalogus

    private static func addonItems(addonID: UUID, catalogType: String, catalogID: String) async -> [MediaItem] {
        guard let addon = AddonStore().load().first(where: { $0.id == addonID }) else { return [] }

        do {
            let client = AIOMetadataClient(baseURL: addon.baseURL)
            let metas = try await client.catalog(type: catalogType, catalogID: catalogID)
            return metas.map { $0.mediaItem() }
        } catch {
            return []
        }
    }
}
