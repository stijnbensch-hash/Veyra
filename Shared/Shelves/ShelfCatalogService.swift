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
            let linked = await linkToTMDB(raw, kind: kind)
            return await enrichWithArtwork(linked, kind: kind)

        case .tmdb(let list, let kind):
            let raw = await tmdbItems(list: list, kind: kind)
            return await linkToTMDB(raw, kind: kind)

        case .addon(let addonID, _, let catalogType, let catalogID, _):
            return await addonItems(addonID: addonID, catalogType: catalogType, catalogID: catalogID)

        case .mediaServer(let serverID, _, let libraryID, _, let kind):
            return await mediaServerItems(
                serverID: serverID,
                libraryID: libraryID,
                kind: kind,
                itemOrder: shelf.effectiveItemOrder,
                sortDirection: shelf.effectiveSortDirection
            )

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
            streamURL: channel.streamURL,
            iptvProviderName: channel.providerName,
            iptvEPGChannelID: channel.tvgID
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
                    rating: item.rating,
                    catalogItemID: item.catalogItemID
                )
            }
        }

        guard let tmdbID = item.tmdbID else { return item }

        // Fase 6 (TMDB-spec, Home cache-first): dezelfde titel komt vaak op meerdere planken en
        // op "Verder met je collecties" voor -- cache-first voorkomt dat elke plek die los
        // opnieuw bevraagt. Alleen de poster/backdrop/genre/score (afgeleid van TMDB) komen uit
        // de cache; `item`-specifieke velden (catalogItemID, lokale overview) blijven van dit
        // exemplaar.
        if let cached = await TMDBMetadataCache.shared.get(tmdbID: tmdbID, kind: kind) {
            return MediaItem(
                id: item.id,
                title: item.title,
                type: item.type,
                imdbID: item.imdbID,
                tmdbID: item.tmdbID,
                overview: item.overview,
                releaseDate: item.releaseDate,
                posterURL: cached.posterURL,
                backdropURL: cached.backdropURL,
                genre: item.genre ?? cached.genre,
                rating: cached.rating ?? item.rating,
                catalogItemID: item.catalogItemID
            )
        }

        if kind == .movie, let token = AppConfiguration.tmdbReadAccessToken {
            if let details = try? await TMDBClient(readAccessToken: token).movieDetails(id: tmdbID) {
                let enriched = MediaItem(
                    id: item.id,
                    title: item.title,
                    type: item.type,
                    imdbID: item.imdbID,
                    tmdbID: item.tmdbID,
                    overview: item.overview,
                    releaseDate: item.releaseDate,
                    posterURL: TMDBImageURLBuilder.poster(details.posterPath),
                    backdropURL: TMDBImageURLBuilder.backdrop(details.backdropPath),
                    genre: item.genre ?? details.genres?.first?.name,
                    rating: details.voteAverage ?? item.rating,
                    catalogItemID: item.catalogItemID
                )
                await TMDBMetadataCache.shared.set(tmdbID: tmdbID, kind: kind, enriched)
                return enriched
            }
        } else if kind == .series, let service = SeriesService() {
            if let details = try? await service.seriesDetails(id: tmdbID) {
                let enriched = MediaItem(
                    id: item.id,
                    title: item.title,
                    type: item.type,
                    imdbID: item.imdbID,
                    tmdbID: item.tmdbID,
                    overview: item.overview,
                    releaseDate: item.releaseDate,
                    posterURL: TMDBImageURLBuilder.poster(details.posterPath),
                    backdropURL: TMDBImageURLBuilder.backdrop(details.backdropPath),
                    genre: item.genre ?? details.genres?.first?.name,
                    rating: details.voteAverage ?? item.rating,
                    catalogItemID: item.catalogItemID
                )
                await TMDBMetadataCache.shared.set(tmdbID: tmdbID, kind: kind, enriched)
                return enriched
            }
        }

        return item
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
            posterURL: TMDBImageURLBuilder.poster(item.posterPath),
            backdropURL: TMDBImageURLBuilder.backdrop(item.backdropPath)
        )
    }

    private static func mediaItem(from movie: TMDBMovie) -> MediaItem {
        MediaItem(
            title: movie.title,
            type: .movie,
            tmdbID: movie.id,
            overview: movie.overview,
            releaseDate: movie.releaseDate,
            posterURL: TMDBImageURLBuilder.poster(movie.posterPath),
            backdropURL: TMDBImageURLBuilder.backdrop(movie.backdropPath),
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
            posterURL: TMDBImageURLBuilder.poster(series.posterPath),
            backdropURL: TMDBImageURLBuilder.backdrop(series.backdropPath),
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
            let kind: ShelfMediaKind = catalogType == "series" ? .series : .movie
            let items = metas.map { $0.mediaItem() }
            // Addon-items komen met een IMDb-ID maar geen TMDB-ID mee — zonder
            // TMDB-ID werken de bestaande detailschermen niet (series lukken
            // dan helemaal niet, zie `ShelfItemDestination`), dus die koppelen
            // we hier alsnog via TMDB's "find by external id".
            return await linkToTMDB(items, kind: kind)
        } catch {
            return []
        }
    }

    // MARK: - TMDB-koppeling voor bronnen zonder eigen TMDB-ID (addon,
    // mediaserver) — vult `tmdbID` in via een IMDb-ID-opzoeking, zodat zulke
    // items dezelfde detailschermen kunnen gebruiken als Trakt/TMDB-items.
    // Items die al een TMDB-ID hebben, of geen IMDb-ID, blijven ongewijzigd.

    private static func linkToTMDB(_ items: [MediaItem], kind: ShelfMediaKind) async -> [MediaItem] {
        guard !items.isEmpty else { return items }

        return await withTaskGroup(of: (Int, MediaItem).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    (index, await resolveTMDBID(item, kind: kind))
                }
            }

            var results = items
            for await (index, resolved) in group {
                results[index] = resolved
            }
            return results
        }
    }

    private static func resolveTMDBID(_ item: MediaItem, kind: ShelfMediaKind) async -> MediaItem {
        guard item.tmdbID == nil else { return item }

        // Fase 9 (IPTV-mapping §50/§51/§52): IMDb-opzoeking, titel-fallback én de persistente
        // mapping-cache zitten nu gecentraliseerd in `TMDBExternalLookup` i.p.v. hier losse
        // aanroepen + eigen cache-logica.
        let year = item.releaseDate.flatMap { date -> Int? in
            guard date.count >= 4 else { return nil }
            return Int(date.prefix(4))
        }
        guard let found = await TMDBExternalLookup.tmdbID(
            forIMDbID: item.imdbID, title: item.title, year: year, kind: kind
        ) else { return item }

        return MediaItem(
            id: item.id,
            title: item.title,
            type: item.type,
            imdbID: item.imdbID,
            tmdbID: found,
            episodeTMDBID: item.episodeTMDBID,
            seasonNumber: item.seasonNumber,
            episodeNumber: item.episodeNumber,
            overview: item.overview,
            releaseDate: item.releaseDate,
            posterURL: item.posterURL,
            backdropURL: item.backdropURL,
            genre: item.genre,
            rating: item.rating,
            streamURL: item.streamURL,
            iptvSeriesID: item.iptvSeriesID,
            iptvProviderName: item.iptvProviderName,
            iptvEPGChannelID: item.iptvEPGChannelID,
            catalogItemID: item.catalogItemID
        )
    }

    // MARK: - Mediaserver-bibliotheek (Jellyfin / VeyraHub)

    private static func mediaServerItems(
        serverID: UUID,
        libraryID: String,
        kind: ShelfMediaKind,
        itemOrder: ShelfItemOrder,
        sortDirection: ShelfSortDirection
    ) async -> [MediaItem] {
        guard let account = MediaServerStore().load().first(where: { $0.id == serverID }) else { return [] }

        let service = JellyfinService(account: account)

        do {
            let items = try await service.items(
                parentID: libraryID,
                includeItemTypes: [kind == .movie ? "Movie" : "Series"],
                sortBy: itemOrder.jellyfinSortBy,
                sortOrder: sortDirection.jellyfinSortOrder
            )
            let mediaItems = items.map { mediaItem(from: $0, service: service, kind: kind) }
            // Als de server geen TMDB-ID meegaf via `ProviderIds` (bv. een
            // echte Jellyfin-server zonder TMDB-metadata-provider), maar wel
            // een IMDb-ID, proberen we die alsnog aan TMDB te koppelen.
            return await linkToTMDB(mediaItems, kind: kind)
        } catch {
            return []
        }
    }

    private static func mediaItem(from item: JellyfinItem, service: JellyfinService, kind: ShelfMediaKind) -> MediaItem {
        MediaItem(
            title: item.displayTitle,
            type: kind == .movie ? .movie : .series,
            imdbID: item.imdbID,
            tmdbID: item.tmdbID,
            overview: item.overview,
            releaseDate: item.productionYear.map(String.init),
            posterURL: service.imageURL(for: item, kind: .primary),
            backdropURL: service.imageURL(for: item, kind: .backdrop),
            genre: item.primaryGenre,
            rating: item.communityRating,
            // Bewaar het eigen Jellyfin/VeyraHub-item-ID — voor items zonder
            // IMDb-ID (zoals losse sportwedstrijden uit een livetv-bibliotheek)
            // kan `JellyfinSourceProvider` hiermee het item rechtstreeks
            // opnieuw opzoeken in plaats van (onbetrouwbaar) op titel te
            // moeten zoeken.
            catalogItemID: item.id
        )
    }
}
