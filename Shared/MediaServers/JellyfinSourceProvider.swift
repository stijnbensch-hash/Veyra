import Foundation

/// Resolves streams from a connected Jellyfin server for a
/// TMDB-matched movie or episode, by title (and year, for movies).
///
/// PlaybackInfo can expose multiple MediaSources. Each playable
/// MediaSource is returned as its own ResolvedSource so the existing
/// SourceSelectionView can show them next to addons and IPTV.
struct JellyfinSourceProvider:
    ResolvedMediaSourceProvider
{
    let account: MediaServerAccount

    var name: String {
        account.name
    }

    private var service:
        JellyfinService
    {
        JellyfinService(
            account: account
        )
    }

    func sources(
        for item: MediaItem
    ) async throws -> [PlayableSource] {
        try await resolvedSources(
            for: item
        )
        .map(\.source)
    }

    func resolvedSources(
        for item: MediaItem
    ) async throws -> [ResolvedSource] {
        // Items die rechtstreeks uit een mediaserver-plank komen (zie
        // `ShelfCatalogService.mediaItem(from: JellyfinItem, ...)`) dragen
        // hun eigen Jellyfin-item-ID mee via `catalogItemID`. Zoek daar
        // eerst op, rechtstreeks bij ID — betrouwbaarder dan titel-zoeken
        // en werkt ook voor items zonder IMDb-ID, zoals losse
        // sportwedstrijden uit een livetv-bibliotheek.
        if let catalogItemID = item.catalogItemID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !catalogItemID.isEmpty {
            debug("catalogItemID lookup: \(catalogItemID)")
            do {
                if let byID = try await service.item(id: catalogItemID) {
                    debug("item(id:) gevonden: \(byID.id) · \(byID.name)")
                    let results = try await playableResults(for: byID)
                    debug("playableResults via catalogItemID: \(results.count)")
                    if !results.isEmpty {
                        return results
                    }
                } else {
                    debug("item(id:) leverde niets op voor \(catalogItemID)")
                }
            } catch {
                debug("item(id:) FOUT: \(error.localizedDescription)")
            }
        } else {
            debug("Geen catalogItemID op dit MediaItem.")
        }

        // Veyra Hub servers can be asked directly by IMDb id through the
        // native API, which doesn't depend on the addon having a
        // searchable catalog the way the Jellyfin title-search path below
        // does (see VeyraHubNativeClient). Try that first, and only fall
        // back to title search if it comes back empty — e.g. no IMDb id
        // was available, or the addon genuinely has nothing for this id.
        if account.isVeyraHub {
            let native = await nativeResolvedSources(
                for: item
            )

            if !native.isEmpty {
                return native
            }
        }

        switch item.type {
        case .movie:
            return try await movieSources(
                for: item
            )

        case .series:
            return try await episodeSources(
                for: item
            )

        case .liveTV, .iptvSeries:
            return []
        }
    }

    // MARK: - Native (Veyra Hub)

    private func nativeResolvedSources(
        for item: MediaItem
    ) async -> [ResolvedSource] {
        guard
            let mediaID =
                VeyraHubNativeClient
                    .nativeMediaID(for: item)
        else {
            debug("native: geen mediaID kunnen bouwen (geen imdbID of catalogItemID).")
            return []
        }

        debug("native REQUEST type=\(item.type) id=\(mediaID)")

        let client =
            VeyraHubNativeClient(
                account: account
            )

        var thrownError: Error?
        let streams: [VeyraHubNativeClient.NativeStream]?
        do {
            streams = try await client.streams(
                type: item.type,
                id: mediaID
            )
        } catch {
            thrownError = error
            streams = nil
        }

        if let thrownError {
            debug("native FOUT: \(thrownError.localizedDescription)")
        } else {
            debug("native Aantal streams: \(streams?.count ?? 0)")
        }

        guard
            let streams
        else {
            return []
        }

        return streams.compactMap { stream in
            Self.resolvedSource(
                from: stream,
                item: item,
                account: account,
                mediaID: mediaID
            )
        }
    }

    private static func resolvedSource(
        from stream: VeyraHubNativeClient.NativeStream,
        item: MediaItem,
        account: MediaServerAccount,
        mediaID: String
    ) -> ResolvedSource? {
        guard
            let url = URL(string: stream.url)
        else {
            return nil
        }

        let candidates = [
            stream.name, stream.title,
        ]

        let displayName =
            candidates
                .compactMap {
                    $0?.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .first { !$0.isEmpty }
            ?? "\(account.name) · \(item.title)"

        let source =
            PlayableSource(
                name: displayName,
                description: stream.description,
                url: url,
                kind: .direct,
                providerName: account.name,
                progressSync: VeyraHubProgressSync(
                    account: account,
                    mediaType: item.type,
                    mediaID: mediaID
                )
            )

        // Groepeer net als een lokaal geïnstalleerde addon: op de naam van
        // de addon die VeyraHub zelf aanroept, niet op de servernaam. Die
        // naam komt altijd mee (HubStream.AddonName is nooit leeg), maar
        // val voor de zekerheid terug op de servernaam.
        let originName =
            Self.cleanOriginName(stream.addonName)
                ?? account.name

        return ResolvedSource(
            source: source,
            originName: originName,
            isFromHub: true
        )
    }

    private static func cleanOriginName(
        _ value: String?
    ) -> String? {
        guard
            let trimmed =
                value?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    // MARK: - Movies

    private func movieSources(
        for item: MediaItem
    ) async throws -> [ResolvedSource] {
        let candidates =
            try await service.search(
                term: item.title,
                includeItemTypes: [
                    "Movie"
                ]
            )

        guard
            let match =
                Self.bestMatch(
                    title: item.title,
                    year:
                        Self.year(
                            from:
                                item.releaseDate
                        ),
                    candidates:
                        candidates
                )
        else {
            return []
        }

        return try await playableResults(
            for: match
        )
    }

    // MARK: - Episodes

    private func episodeSources(
        for item: MediaItem
    ) async throws -> [ResolvedSource] {
        guard
            let seasonNumber =
                item.seasonNumber,
            let episodeNumber =
                item.episodeNumber
        else {
            return []
        }

        let seriesCandidates =
            try await service.search(
                term: item.title,
                includeItemTypes: [
                    "Series"
                ]
            )

        guard
            let series =
                Self.bestMatch(
                    title: item.title,
                    year: nil,
                    candidates:
                        seriesCandidates
                )
        else {
            return []
        }

        let episodes =
            try await service.episodes(
                seriesID: series.id
            )

        guard
            let episode =
                episodes.first(
                    where: {
                        $0.parentIndexNumber
                            == seasonNumber
                            && $0.indexNumber
                                == episodeNumber
                    }
                )
        else {
            return []
        }

        return try await playableResults(
            for: episode
        )
    }

    // MARK: - Building results

    private func playableResults(
        for jellyfinItem: JellyfinItem
    ) async throws -> [ResolvedSource] {
        let playbackInfo =
            try await service.playbackInfo(
                for: jellyfinItem
            )

        var results:
            [ResolvedSource] = []

        for mediaSource
            in playbackInfo.mediaSources
        {
            guard
                let url =
                    service.playbackURL(
                        for:
                            jellyfinItem,
                        mediaSource:
                            mediaSource
                    )
            else {
                continue
            }

            let sourceName =
                mediaSource.name?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            let displayName:
                String

            if
                let sourceName,
                !sourceName.isEmpty
            {
                displayName =
                    sourceName
            } else {
                displayName =
                    "\(account.name) · \(jellyfinItem.displayTitle)"
            }

            let description =
                sourceDescription(
                    mediaSource:
                        mediaSource,
                    jellyfinItem:
                        jellyfinItem
                )

            let source =
                PlayableSource(
                    name:
                        displayName,
                    description:
                        description,
                    url:
                        url,
                    kind:
                        .direct,
                    providerName:
                        account.name
                )

            // Zelfde groepering als het native pad hierboven: op de naam
            // van de VeyraHub-addon (als de server dat meestuurt), niet op
            // de servernaam. Een echte Jellyfin/Emby-server stuurt geen
            // AddonName mee, dus die blijft gewoon op de servernaam vallen.
            let originName =
                Self.cleanOriginName(
                    mediaSource.addonName
                )
                ?? account.name

            results.append(
                ResolvedSource(
                    source:
                        source,
                    originName:
                        originName,
                    isFromHub:
                        account.isVeyraHub
                )
            )
        }

        return results
    }

    private func sourceDescription(
        mediaSource: JellyfinMediaSource,
        jellyfinItem: JellyfinItem
    ) -> String? {
        var parts:
            [String] = []

        if
            let container =
                mediaSource.container?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !container.isEmpty
        {
            parts.append(
                container.uppercased()
            )
        }

        if
            let size =
                mediaSource.size,
            size > 0
        {
            parts.append(
                ByteCountFormatter
                    .string(
                        fromByteCount:
                            size,
                        countStyle:
                            .file
                    )
            )
        }

        if
            let bitrate =
                mediaSource.bitrate,
            bitrate > 0
        {
            let megabits =
                Double(bitrate)
                    / 1_000_000

            parts.append(
                String(
                    format:
                        "%.1f Mbps",
                    megabits
                )
            )
        }

        if !parts.isEmpty {
            return parts.joined(
                separator: " · "
            )
        }

        return jellyfinItem.overview
    }

    // MARK: - Matching

    private static func bestMatch(
        title: String,
        year: Int?,
        candidates: [JellyfinItem]
    ) -> JellyfinItem? {
        let normalizedTitle =
            normalize(title)

        let titleMatches =
            candidates.filter {
                normalize($0.name)
                    == normalizedTitle
            }

        guard
            !titleMatches.isEmpty
        else {
            return nil
        }

        guard
            let year
        else {
            return titleMatches.first
        }

        return titleMatches.first {
            $0.productionYear == year
        }
            ?? titleMatches.first
    }

    private static func normalize(
        _ value: String
    ) -> String {
        value
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .lowercased()
    }

    private static func year(
        from releaseDate: String?
    ) -> Int? {
        guard
            let releaseDate,
            releaseDate.count >= 4
        else {
            return nil
        }

        return Int(
            releaseDate.prefix(4)
        )
    }


    // MARK: - Debug

    private func debug(
        _ message: String
    ) {
        #if DEBUG
        print(
            "[JellyfinSourceProvider][\(name)] \(message)"
        )
        #endif
    }

}
