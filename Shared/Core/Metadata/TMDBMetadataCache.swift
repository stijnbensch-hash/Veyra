// TMDBMetadataCache.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 6 ("VEYRA — TMDB PERFORMANCE & CACHING REFACTOR" spec §7/§44/§53: cache-first Home +
// "geen tweede los TMDB-systeem voor Collections" + canonical metadata store). Eén gedeelde,
// sessie-lange in-memory cache van opgeloste `MediaItem`-metadata per TMDB-ID, gebruikt door
// zowel `ShelfCatalogService` (Home/planken) als `VeyraCollectionMetadataResolver`
// (Collections) -- die bevroegen voorheen onafhankelijk van elkaar dezelfde film/serie opnieuw
// zodra die op meerdere plekken (Home, "Verder met je collecties", een plank) voorkwam.
actor TMDBMetadataCache {
    static let shared = TMDBMetadataCache()

    private struct Key: Hashable {
        let tmdbID: Int
        let kind: ShelfMediaKind
    }

    private var items: [Key: MediaItem] = [:]

    func get(tmdbID: Int, kind: ShelfMediaKind) async -> MediaItem? {
        let media = items[Key(tmdbID: tmdbID, kind: kind)]
        if media != nil {
            #if DEBUG
            print("[TMDB] \(kind.rawValue) \(tmdbID) cache=memory")
            #endif
            await TMDBDiagnostics.shared.recordCacheHit()
        }
        return media
    }

    func set(tmdbID: Int, kind: ShelfMediaKind, _ media: MediaItem) {
        items[Key(tmdbID: tmdbID, kind: kind)] = media
    }
}
