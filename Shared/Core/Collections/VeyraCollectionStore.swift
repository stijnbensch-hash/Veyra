// VeyraCollectionStore.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Persistence + reactive state voor "Veyra Collections" -- Fase 2.
// Zelfde UserDefaults+JSON-persistencepatroon als VeyraStreamingStore/VeyraCollectionsStore
// (VeyraBentoCatalog.swift), maar als ObservableObject-singleton (zoals TraktStore) zodat een
// wijziging in de ene view (bv. "Toevoegen aan collectie" vanuit Movie Detail) onmiddellijk
// zichtbaar wordt in elke andere view (Collections-browser, Home-kaart) zonder app restart
// (spec §57) -- de stateless enum-stores elders in de app vereisen dat elke view zelf herlaadt,
// wat hier niet volstaat.
//
// `defaults` is injecteerbaar (i.p.v. hardcoded `.standard`) zodat Tests/CollectionsChecks.swift
// een geïsoleerde UserDefaults-suite kan gebruiken, zelfde aanpak als SubtitlePreferences.

import Foundation
import Combine

@MainActor
final class VeyraCollectionStore: ObservableObject {
    static let shared = VeyraCollectionStore()

    @Published private(set) var collections: [VeyraCollection] = []

    private let defaults: UserDefaults
    private static let key = "veyra.collections.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        collections = Self.load(defaults: defaults)
        // Fase 10: `veyra.collections.v1` gaat voortaan mee in VeyraHubSyncService's
        // generieke settings-sync (spec §58) -- die schrijft inkomende wijzigingen enkel
        // naar UserDefaults en seint dat via de bestaande `.veyraShelfConfigurationDidChange`
        // (dezelfde notificatie als voor shelves/hero/streaming). Zonder deze observer zou de
        // al geladen `collections`-cache stil blijven staan tot een herstart (spec §57: "geen
        // app restart" geldt hier ook voor sync vanaf een ander apparaat).
        NotificationCenter.default.addObserver(self, selector: #selector(reloadFromDefaults),
                                                name: .veyraShelfConfigurationDidChange, object: nil)
    }

    @objc private func reloadFromDefaults() {
        let fresh = Self.load(defaults: defaults)
        guard fresh != collections else { return }
        collections = fresh
    }

    // MARK: - Persistence

    private static func load(defaults: UserDefaults) -> [VeyraCollection] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([VeyraCollection].self, from: data) else {
            return []
        }
        return decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(collections) else { return }
        defaults.set(data, forKey: Self.key)
    }

    // MARK: - Collecties

    @discardableResult
    func create(name: String, description: String? = nil, sortMode: VeyraCollectionSortMode = .releaseDate,
                type: VeyraCollectionType = .manual) -> VeyraCollection {
        let collection = VeyraCollection(name: name, collectionDescription: description, type: type, sortMode: sortMode)
        collections.append(collection)
        save()
        return collection
    }

    /// `description`/`artworkReference` zijn dubbel-optioneel: `nil` (niet meegeven) = laat
    /// ongewijzigd, `.some(nil)` = wis expliciet het veld.
    func update(_ id: VeyraCollection.ID, name: String? = nil, description: String?? = nil,
                sortMode: VeyraCollectionSortMode? = nil, artworkReference: String?? = nil,
                artworkPosition: VeyraArtworkPosition?? = nil, clearLogoReference: String?? = nil) {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        if let name { collections[index].name = name }
        if let description { collections[index].collectionDescription = description }
        if let sortMode { collections[index].sortMode = sortMode }
        if let artworkReference { collections[index].artworkReference = artworkReference }
        if let artworkPosition { collections[index].artworkPosition = artworkPosition }
        if let clearLogoReference { collections[index].clearLogoReference = clearLogoReference }
        collections[index].updatedAt = Date()
        save()
    }

    func delete(_ id: VeyraCollection.ID) {
        guard collections.contains(where: { $0.id == id }) else { return }
        collections.removeAll { $0.id == id }
        save()
    }

    func collection(_ id: VeyraCollection.ID) -> VeyraCollection? {
        collections.first { $0.id == id }
    }

    /// Verplaatst een collectie binnen de handmatige volgorde van de "Jouw Collecties"-lijst
    /// (herschikken, zelfde opzet als `moveItem` voor films binnen een collectie, spec §37: geen
    /// fragiele drag-and-drop op tvOS -- "verplaats naar links/rechts/begin/einde" roept dit aan).
    /// De volgorde van `collections` ZELF is hier de bewaarde volgorde (geen apart indexveld nodig).
    func moveCollection(_ id: VeyraCollection.ID, to destinationIndex: Int) {
        guard let from = collections.firstIndex(where: { $0.id == id }) else { return }
        let collection = collections.remove(at: from)
        let clampedDestination = max(0, min(destinationIndex, collections.count))
        collections.insert(collection, at: clampedDestination)
        save()
    }

    /// Bewaar een officiële collectie als persoonlijke kopie (spec §35/§36) -- de originele
    /// officiële collectie blijft onaangetast, dit maakt enkel een nieuwe eigen `VeyraCollection`.
    @discardableResult
    func saveAsOwnCollection(name: String, tmdbCollectionID: Int, items: [VeyraCollectionItem]) -> VeyraCollection {
        var collection = VeyraCollection(name: name, type: .manual, items: items, sortMode: .manual)
        collection.copiedFromTMDBCollectionID = tmdbCollectionID
        collections.append(collection)
        save()
        return collection
    }

    // MARK: - Items

    /// Voegt `item` toe aan de collectie, met duplicate-prevention (spec §42/§43). Geeft `true`
    /// terug als het item effectief toegevoegd werd (`false` = stond al in de collectie, of de
    /// collectie bestaat niet).
    @discardableResult
    func addItem(_ item: MediaItem, to collectionID: VeyraCollection.ID) -> Bool {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return false }
        guard !collections[index].items.contains(where: { $0.matches(item) }) else { return false }

        let nextIndex = (collections[index].items.map(\.manualSortIndex).max() ?? -1) + 1
        collections[index].items.append(VeyraCollectionItem(item: item, manualSortIndex: nextIndex))
        collections[index].updatedAt = Date()
        save()
        return true
    }

    /// Verwijdert alleen de membership (spec §21) -- raakt nooit de film zelf, watch history of
    /// Trakt-status.
    func removeItem(_ itemID: VeyraCollectionItem.ID, from collectionID: VeyraCollection.ID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        collections[index].items.removeAll { $0.id == itemID }
        collections[index].updatedAt = Date()
        save()
    }

    /// Verplaatst een item binnen de handmatige volgorde van een collectie (spec §37: geen
    /// fragiele drag-and-drop op tvOS -- "verplaats naar links/rechts/begin/einde" roept dit aan
    /// met de juiste `destinationIndex`; iOS/iPad kan hier ook `.onMove`-offsets op mappen, spec §38).
    func moveItem(_ itemID: VeyraCollectionItem.ID, in collectionID: VeyraCollection.ID, to destinationIndex: Int) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        var ordered = collections[index].items.sorted { $0.manualSortIndex < $1.manualSortIndex }
        guard let from = ordered.firstIndex(where: { $0.id == itemID }) else { return }
        let item = ordered.remove(at: from)
        let clampedDestination = max(0, min(destinationIndex, ordered.count))
        ordered.insert(item, at: clampedDestination)

        for (newIndex, orderedItem) in ordered.enumerated() {
            if let itemIndex = collections[index].items.firstIndex(where: { $0.id == orderedItem.id }) {
                collections[index].items[itemIndex].manualSortIndex = newIndex
            }
        }
        collections[index].updatedAt = Date()
        save()
    }

    // MARK: - Chronologie (spec §35-§41)

    /// `true` als voor ELK item in de collectie al een chronologische positie is ingesteld --
    /// anders tonen we "Geen chronologische volgorde beschikbaar" i.p.v. een gegokte volgorde
    /// (spec §36/§38).
    func hasChronology(_ collectionID: VeyraCollection.ID) -> Bool {
        guard let collection = collections.first(where: { $0.id == collectionID }), !collection.items.isEmpty
        else { return false }
        return collection.items.allSatisfy { $0.chronologyIndex != nil }
    }

    /// Start de chronologie-editor vanaf de huidige handmatige volgorde (i.p.v. een lege/
    /// willekeurige lijst) zodat de gebruiker vanaf een zinvol beginpunt kan herschikken -- dit
    /// is zelf nog GEEN gegokte chronologie, pas na een expliciete "Chronologie instellen" door de
    /// gebruiker telt de volgorde als user-defined (spec §36).
    func seedChronologyIfNeeded(_ collectionID: VeyraCollection.ID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        guard collections[index].items.contains(where: { $0.chronologyIndex == nil }) else { return }
        let ordered = collections[index].items.sorted { $0.manualSortIndex < $1.manualSortIndex }
        for (newIndex, item) in ordered.enumerated() {
            if let itemIndex = collections[index].items.firstIndex(where: { $0.id == item.id }) {
                collections[index].items[itemIndex].chronologyIndex = newIndex
            }
        }
        collections[index].updatedAt = Date()
        save()
    }

    /// Verplaatst een item binnen de chronologische volgorde (spec §39) -- apart van
    /// `moveItem`/`manualSortIndex`, wisselen van sortering mag collection membership of de
    /// andere volgorde-informatie niet overschrijven (spec §42).
    func moveChronology(_ itemID: VeyraCollectionItem.ID, in collectionID: VeyraCollection.ID, to destinationIndex: Int) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        var ordered = collections[index].items.sorted {
            ($0.chronologyIndex ?? $0.manualSortIndex) < ($1.chronologyIndex ?? $1.manualSortIndex)
        }
        guard let from = ordered.firstIndex(where: { $0.id == itemID }) else { return }
        let item = ordered.remove(at: from)
        let clampedDestination = max(0, min(destinationIndex, ordered.count))
        ordered.insert(item, at: clampedDestination)

        for (newIndex, orderedItem) in ordered.enumerated() {
            if let itemIndex = collections[index].items.firstIndex(where: { $0.id == orderedItem.id }) {
                collections[index].items[itemIndex].chronologyIndex = newIndex
            }
        }
        collections[index].updatedAt = Date()
        save()
    }

    // MARK: - Membership-overzicht

    /// Alle collecties waar `item` al in zit (spec §18/§19 "Toevoegen aan collectie"-lijstje).
    func collectionsContaining(_ item: MediaItem) -> [VeyraCollection] {
        collections.filter { collection in collection.items.contains { $0.matches(item) } }
    }

    func isItem(_ item: MediaItem, in collectionID: VeyraCollection.ID) -> Bool {
        collections.first { $0.id == collectionID }?.items.contains { $0.matches(item) } ?? false
    }
}
