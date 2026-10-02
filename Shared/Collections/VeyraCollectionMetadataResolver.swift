// VeyraCollectionMetadataResolver.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Haalt titel/poster/backdrop/jaar op voor collectie-items (spec §17: `VeyraCollectionItem`
// bewaart zelf GEEN metadata, enkel identiteit) -- zelfde concurrente TMDB-ophaalpatroon als
// `ShelfCatalogService.enrichWithArtwork`/`enrich` (Shared/Shelves/ShelfCatalogService.swift,
// private en dus niet herbruikbaar van buitenaf), maar toegespitst op `VeyraCollectionItem`.
// Fase 1 van Collections is bewust films-only (spec §41), dus enkel `TMDBClient.movieDetails(id:)`.

import Foundation

/// Eén collectie-item met zijn opgeloste metadata, voor weergave in Collection Stage/Journey.
struct VeyraResolvedCollectionItem: Identifiable, Hashable {
    let collectionItemID: UUID
    let manualSortIndex: Int
    let chronologyIndex: Int?
    let addedAt: Date
    let media: MediaItem

    var id: UUID { collectionItemID }
}

enum VeyraCollectionMetadataResolver {
    static func resolve(_ items: [VeyraCollectionItem]) async -> [VeyraResolvedCollectionItem] {
        guard !items.isEmpty else { return [] }

        return await withTaskGroup(of: (Int, VeyraResolvedCollectionItem).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask { (index, await resolve(item)) }
            }

            var results = [VeyraResolvedCollectionItem?](repeating: nil, count: items.count)
            for await (index, resolved) in group { results[index] = resolved }
            return results.compactMap { $0 }
        }
    }

    private static func resolve(_ item: VeyraCollectionItem) async -> VeyraResolvedCollectionItem {
        var media = MediaItem(title: "?", type: item.mediaType, imdbID: item.imdbID, tmdbID: item.tmdbID)

        if let tmdbID = item.tmdbID {
            // Fase 6 (TMDB-spec, §44/§53): gedeelde cache met Home/Shelves i.p.v. een eigen los
            // Collections-systeem -- Home ("Jouw Collecties", "Verder met je collecties") en de
            // Collections-browser bevroegen voorheen onafhankelijk van elkaar vaak dezelfde
            // films tegelijk op het startscherm. Collections is vooralsnog films-only (spec §41).
            if let cached = await TMDBMetadataCache.shared.get(tmdbID: tmdbID, kind: .movie) {
                media = cached
            } else if let token = AppConfiguration.tmdbReadAccessToken,
                      let details = try? await TMDBClient(readAccessToken: token).movieDetails(id: tmdbID) {
                media = MediaItem(
                    title: details.title,
                    type: item.mediaType,
                    imdbID: item.imdbID,
                    tmdbID: item.tmdbID,
                    overview: details.overview,
                    releaseDate: details.releaseDate,
                    posterURL: TMDBImageURLBuilder.poster(details.posterPath),
                    backdropURL: TMDBImageURLBuilder.backdrop(details.backdropPath),
                    genre: details.genres?.first?.name,
                    rating: details.voteAverage
                )
                await TMDBMetadataCache.shared.set(tmdbID: tmdbID, kind: .movie, media)
            }
        }

        return VeyraResolvedCollectionItem(collectionItemID: item.id, manualSortIndex: item.manualSortIndex,
                                           chronologyIndex: item.chronologyIndex, addedAt: item.addedAt, media: media)
    }

}
