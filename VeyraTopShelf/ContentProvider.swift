//
//  ContentProvider.swift
//  VeyraTopShelf
//
//  Created by Stijn Bensch on 25/09/2026.
//

import TVServices

class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        let items = await TopShelfTraktAPI.continueWatching(limit: 10)
        guard !items.isEmpty else { return nil }

        var sectionedItems: [TVTopShelfSectionedItem] = []

        for (index, item) in items.enumerated() {
            let sectionedItem = TVTopShelfSectionedItem(identifier: "continue-watching-\(index)")
            sectionedItem.title = item.subtitle.map { "\(item.title) · \($0)" } ?? item.title
            sectionedItem.imageShape = .hdtv

            if let tmdbID = item.tmdbID,
               let backdropURL = await TopShelfTMDBArtwork.backdropURL(isShow: item.isShow, tmdbID: tmdbID) {
                // `ImageTraits` is enkel een schaal-aanduiding (geen
                // stijl/grootte, ondanks wat de naam doet vermoeden) —
                // het systeem kiest zelf de passende variant voor het
                // apparaat.
                sectionedItem.setImageURL(backdropURL, for: .screenScale1x)
                sectionedItem.setImageURL(backdropURL, for: .screenScale2x)
            }

            // Geen displayURL/playURL: zonder een geregistreerd
            // URL-schema voor Veyra opent een tik op dit item gewoon de
            // app zelf (het systeemstandaardgedrag), zonder door te
            // linken naar deze specifieke titel.
            sectionedItems.append(sectionedItem)
        }

        guard !sectionedItems.isEmpty else { return nil }

        let collection = TVTopShelfItemCollection(items: sectionedItems)
        collection.title = "Verder kijken"

        return TVTopShelfSectionedContent(sections: [collection])
    }

}
