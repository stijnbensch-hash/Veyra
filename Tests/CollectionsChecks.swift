import Foundation

@main
struct CollectionsChecks {
    @MainActor static func main() async throws {
        let suite = "Veyra.CollectionsTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = VeyraCollectionStore(defaults: defaults)
        precondition(store.collections.isEmpty, "lege store bij start")

        // create
        let collection = store.create(name: "Sci-Fi Classics", description: "Mijn favoriete sci-fi", sortMode: .manual)
        precondition(store.collections.count == 1, "create voegt één collectie toe")
        precondition(store.collections[0].name == "Sci-Fi Classics")
        precondition(store.collections[0].collectionDescription == "Mijn favoriete sci-fi")
        precondition(store.collections[0].type == .manual)
        precondition(store.collections[0].isEmpty)

        // rename + beschrijving wissen
        store.update(collection.id, name: "Sci-Fi", description: .some(nil))
        precondition(store.collections[0].name == "Sci-Fi", "rename werkt")
        precondition(store.collections[0].collectionDescription == nil, "beschrijving expliciet gewist")

        // add
        let alien = MediaItem(title: "Alien", type: .movie, tmdbID: 348)
        let dune = MediaItem(title: "Dune", type: .movie, tmdbID: 438631)
        precondition(store.addItem(alien, to: collection.id) == true, "alien toegevoegd")
        precondition(store.addItem(dune, to: collection.id) == true, "dune toegevoegd")
        precondition(store.collections[0].items.count == 2, "twee films in de collectie")

        // duplicate prevention (zelfde MediaItem-instance nogmaals)
        precondition(store.addItem(alien, to: collection.id) == false, "zelfde film niet dubbel toegevoegd")
        precondition(store.collections[0].items.count == 2, "aantal blijft 2 na dubbele poging")

        // duplicate prevention via canonical ID-match (andere MediaItem-instance, zelfde tmdbID)
        let alienAgain = MediaItem(title: "Alien", type: .movie, tmdbID: 348)
        precondition(store.addItem(alienAgain, to: collection.id) == false, "duplicate via canonical tmdbID herkend")
        precondition(store.collections[0].items.count == 2)

        // reorder
        precondition(store.collections[0].orderedItems.map(\.mediaID) == ["tmdb:348", "tmdb:438631"], "toevoegvolgorde klopt")
        if let duneItemID = store.collections[0].items.first(where: { $0.mediaID == "tmdb:438631" })?.id {
            store.moveItem(duneItemID, in: collection.id, to: 0)
        }
        precondition(store.collections[0].orderedItems.map(\.mediaID) == ["tmdb:438631", "tmdb:348"], "reorder naar begin werkt")

        // membership-overzicht
        let membership = store.collectionsContaining(dune)
        precondition(membership.count == 1 && membership[0].id == collection.id, "collectie gevonden via membership-check")
        precondition(store.isItem(alien, in: collection.id), "isItem herkent alien")

        // remove (alleen membership, geen film/watch-state)
        if let alienItemID = store.collections[0].items.first(where: { $0.mediaID == "tmdb:348" })?.id {
            store.removeItem(alienItemID, from: collection.id)
        }
        precondition(store.collections[0].items.count == 1, "alien verwijderd uit collectie")
        precondition(store.collections[0].items.first?.mediaID == "tmdb:438631", "dune blijft over")

        // persistence: nieuwe store-instance op dezelfde UserDefaults-suite laadt dezelfde staat
        let reloaded = VeyraCollectionStore(defaults: defaults)
        precondition(reloaded.collections.count == 1, "collectie overleeft herladen")
        precondition(reloaded.collections[0].items.count == 1)
        precondition(reloaded.collections[0].name == "Sci-Fi")
        precondition(reloaded.collections[0].items.first?.mediaID == "tmdb:438631")

        // delete
        store.delete(collection.id)
        precondition(store.collections.isEmpty, "delete verwijdert de collectie")
        let reloadedAfterDelete = VeyraCollectionStore(defaults: defaults)
        precondition(reloadedAfterDelete.collections.isEmpty, "delete is persistent")

        print("PASS collections create/rename/delete/add/remove/duplicate-prevention/reorder/persistence.")
    }
}
