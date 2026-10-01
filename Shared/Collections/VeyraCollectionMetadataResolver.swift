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

// In-memory cache, per TMDB-ID: Home ("Jouw Collecties", "Verder met je collecties") en de
// Collections-browser resolven onafhankelijk van elkaar vaak dezelfde films tegelijk op het
// startscherm -- zonder deze cache leidde dat tot tientallen/honderden gelijktijdige TMDB-
// aanvragen bij elke Home-load, wat de tvOS-app liet vasthangen. Geldig voor de hele sessie
// (films veranderen hun metadata niet tijdens een sessie).
private actor VeyraCollectionMetadataCache {
    static let shared = VeyraCollectionMetadataCache()
    private var items: [Int: MediaItem] = [:]

    func get(_ tmdbID: Int) -> MediaItem? { items[tmdbID] }
    func set(_ tmdbID: Int, _ media: MediaItem) { items[tmdbID] = media }
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
            if let cached = await VeyraCollectionMetadataCache.shared.get(tmdbID) {
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
                    posterURL: imageURL(details.posterPath),
                    backdropURL: imageURL(details.backdropPath, size: "w1280"),
                    genre: details.genres?.first?.name,
                    rating: details.voteAverage
                )
                await VeyraCollectionMetadataCache.shared.set(tmdbID, media)
            }
        }

        return VeyraResolvedCollectionItem(collectionItemID: item.id, manualSortIndex: item.manualSortIndex,
                                           chronologyIndex: item.chronologyIndex, addedAt: item.addedAt, media: media)
    }

    private static func imageURL(_ path: String?, size: String = "w500") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}
