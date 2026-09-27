//
//  ContentProvider.swift
//  VeyraTopShelf
//
//  Created by Stijn Bensch on 25/09/2026.
//

import TVServices

class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        let items = await TopShelfTraktAPI.continueWatching(limit: 80)
        guard !items.isEmpty else { return nil }

        let sectionedItems: [TVTopShelfSectionedItem] = items.map { item in
            let sectionedItem = TVTopShelfSectionedItem(identifier: item.id)
            sectionedItem.title = [item.title, item.subtitle, item.episodeTitle]
                .compactMap { $0 }
                .joined(separator: " · ")
            sectionedItem.imageShape = .hdtv
            sectionedItem.playbackProgress = item.playbackProgress
            return sectionedItem
        }

        // Top Shelf leest de afbeeldingen buiten de extensie. Geef daarom
        // publieke HTTPS-adressen door in plaats van bestanden uit de
        // privécache van de extensie. Alleen de kleine TMDB-metadata wordt
        // hier opgehaald; het systeem haalt de afbeeldingen zelf binnen.
        for start in stride(from: 0, to: items.count, by: 12) {
            let batch = start..<min(start + 12, items.count)
            let artwork = await withTaskGroup(of: (Int, URL?).self) { group in
                for index in batch {
                    let item = items[index]
                    group.addTask {
                        guard let tmdbID = item.tmdbID else { return (index, nil) }
                        let urls = await TopShelfTMDBArtwork.imageURLs(
                            isShow: item.isShow, tmdbID: tmdbID
                        )
                        return (index, urls.backdrop ?? urls.logo ?? urls.poster)
                    }
                }
                var results: [(Int, URL?)] = []
                for await result in group { results.append(result) }
                return results
            }
            for (index, url) in artwork {
                guard let url else { continue }
                sectionedItems[index].setImageURL(url, for: .screenScale1x)
                sectionedItems[index].setImageURL(url, for: .screenScale2x)
            }
        }

        // Zonder eigen URL-schema opent een tik op een kaart de app.

        let collection = TVTopShelfItemCollection(items: sectionedItems)
        collection.title = "Verder kijken"

        return TVTopShelfSectionedContent(sections: [collection])
    }

}
