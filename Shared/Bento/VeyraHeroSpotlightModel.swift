// VeyraHeroSpotlightModel.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Laadt en mixt de items voor de nieuwe Home-hero uit de ingestelde
// primaire/secundaire bron (TMDB- of Trakt-lijst) — hergebruikt dezelfde
// ophaallaag als de "Planken" (ShelfCatalogService) en de clearlogo-service
// van de detailschermen.

import Foundation

nonisolated struct HeroSpotlightItem: Identifiable, Equatable {
    let id: String
    let title: String
    let overview: String?
    let backdropURL: URL?
    let posterURL: URL?
    let logoURL: URL?
    let rating: Double?
    let year: String?
    let genre: String?
    let isMovie: Bool
    let mediaItem: MediaItem

    static func == (lhs: HeroSpotlightItem, rhs: HeroSpotlightItem) -> Bool { lhs.id == rhs.id }
}

enum HeroSpotlightLoader {
    /// Max. aantal items in de carrousel -- lang genoeg voor een levendige
    /// wissel, kort genoeg om niet te veel clearlogo's tegelijk op te halen.
    private static let limit = 14

    static func load(settings: HeroSpotlightSettings) async -> [HeroSpotlightItem] {
        async let primary = mediaItems(for: settings.primarySource)
        async let secondary = mediaItems(for: settings.secondarySource)

        let mixed = interleave(await primary, await secondary)
            .filter { $0.backdropURL != nil }
            .prefix(limit)
        let ordered = Array(mixed)

        let enriched = await withTaskGroup(of: (Int, HeroSpotlightItem).self) { group in
            for (index, item) in ordered.enumerated() {
                group.addTask { (index, await makeSpotlightItem(item)) }
            }
            var results = [HeroSpotlightItem?](repeating: nil, count: ordered.count)
            for await (index, item) in group { results[index] = item }
            return results.compactMap { $0 }
        }
        return enriched
    }

    private static func mediaItems(for source: ShelfSource?) async -> [MediaItem] {
        guard let source else { return [] }
        let shelf = Shelf(title: "", source: source)
        return await ShelfCatalogService.items(for: shelf)
    }

    /// Beide bronnen door elkaar gemixt i.p.v. na elkaar.
    private static func interleave(_ a: [MediaItem], _ b: [MediaItem]) -> [MediaItem] {
        var result: [MediaItem] = []
        var ai = a.makeIterator()
        var bi = b.makeIterator()
        while true {
            var addedAny = false
            if let next = ai.next() { result.append(next); addedAny = true }
            if let next = bi.next() { result.append(next); addedAny = true }
            if !addedAny { break }
        }
        return result
    }

    private static func makeSpotlightItem(_ item: MediaItem) async -> HeroSpotlightItem {
        let logo = await ArtworkResolver.shared.clearLogoURL(for: item)
        let year: String? = item.releaseDate.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil }
        return HeroSpotlightItem(
            id: item.id.uuidString,
            title: item.title,
            overview: item.overview,
            backdropURL: item.backdropURL,
            posterURL: item.posterURL,
            logoURL: logo,
            rating: item.rating,
            year: year,
            genre: item.genre,
            isMovie: item.type == .movie,
            mediaItem: item
        )
    }
}
