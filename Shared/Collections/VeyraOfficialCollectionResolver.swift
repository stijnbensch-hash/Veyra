// VeyraOfficialCollectionResolver.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Haalt alle delen van een officiële TMDB-collectie op (Fase 7, spec §33/§34) en zet ze om naar
// `VeyraResolvedCollectionItem` -- precies hetzelfde type dat `VeyraCollectionMetadataResolver`
// voor eigen collecties produceert, zodat `VeyraCollectionDetailView` dezelfde Stage/Journey-
// componenten kan hergebruiken voor officiële EN eigen collecties (spec §34).
// Niet-persistent: pas "Bewaar als eigen collectie" (spec §35/§36) schrijft dit naar
// `VeyraCollectionStore`.

import Foundation

enum VeyraOfficialCollectionResolver {
    static func resolve(tmdbCollectionID: Int) async -> (description: String?, items: [VeyraResolvedCollectionItem]) {
        guard let token = AppConfiguration.tmdbReadAccessToken else { return (nil, []) }
        guard let detail = try? await TMDBClient(readAccessToken: token).collectionDetails(id: tmdbCollectionID) else {
            return (nil, [])
        }
        let ordered = detail.parts.sorted { ($0.releaseDate ?? "9999") < ($1.releaseDate ?? "9999") }
        let items = ordered.enumerated().map { index, part -> VeyraResolvedCollectionItem in
            let media = MediaItem(
                title: part.title ?? detail.name, type: .movie, imdbID: nil, tmdbID: part.id,
                overview: part.overview, releaseDate: part.releaseDate,
                posterURL: TMDBImageURLBuilder.poster(part.posterPath),
                backdropURL: TMDBImageURLBuilder.backdrop(part.backdropPath)
            )
            return VeyraResolvedCollectionItem(collectionItemID: UUID(), manualSortIndex: index, chronologyIndex: nil,
                                               addedAt: Date(), media: media)
        }
        return (detail.overview, items)
    }

}
