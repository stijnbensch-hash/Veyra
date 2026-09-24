// VeyraHomeLayout.swift
// Wat er op Home staat is per gebruiker instelbaar: welke blokken, in welke volgorde, en een preset als startpunt.
// Alles wordt als één klein JSON-document bewaard (UserDefaults) en via VeyraHub tussen apparaten gesynchroniseerd.

import SwiftUI

extension Notification.Name {
    static let veyraHomeLayoutDidChange = Notification.Name("VeyraHomeLayoutDidChange")
}

/// De indeling van Home: volgorde en zichtbaarheid van de rasterblokken, plus Sport en eigen planken.
nonisolated struct VeyraHomeLayout: Codable, Equatable, Sendable {
    var order: [String]
    var hidden: [String]
    var showSport: Bool
    var showShelves: Bool
    var preset: String?

    static let defaultOrder: [String] = [
        "verder", "releasesFilms", "releasesSeries", "volgende", "live", "vandaag",
        "iptvFilms", "iptvSeries", "streaming", "collecties"
    ]

    static let standard = VeyraHomeLayout(order: defaultOrder, hidden: [], showSport: true, showShelves: true, preset: "alles")

    /// Alle blokken in de gekozen volgorde; nieuwe blokken uit een latere versie komen er achteraan bij.
    var orderedTiles: [BentoTile] {
        var tiles = order.compactMap { BentoTile(rawValue: $0) }.filter { BentoTile.configurable.contains($0) }
        for tile in BentoTile.configurable where !tiles.contains(tile) { tiles.append(tile) }
        return tiles
    }

    func isVisible(_ tile: BentoTile) -> Bool { !hidden.contains(tile.rawValue) }

    mutating func setVisible(_ visible: Bool, _ tile: BentoTile) {
        hidden.removeAll { $0 == tile.rawValue }
        if !visible { hidden.append(tile.rawValue) }
        preset = nil
    }

    mutating func move(_ tile: BentoTile, by offset: Int) {
        var tiles = orderedTiles
        guard let index = tiles.firstIndex(of: tile) else { return }
        let target = index + offset
        guard tiles.indices.contains(target) else { return }
        tiles.swapAt(index, target)
        order = tiles.map(\.rawValue)
        preset = nil
    }

    /// Voor `.onMove` op iOS (sleepbalkje in de lijst).
    mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var tiles = orderedTiles
        tiles.move(fromOffsets: offsets, toOffset: destination)
        order = tiles.map(\.rawValue)
        preset = nil
    }
}

/// Een startpunt voor de indeling, te kiezen bij de eerste start en later in Instellingen.
nonisolated struct VeyraHomePreset: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let layout: VeyraHomeLayout

    private static func make(_ id: String, order: [String], show: [String], sport: Bool, shelves: Bool = true) -> VeyraHomeLayout {
        let rest = VeyraHomeLayout.defaultOrder.filter { !order.contains($0) }
        return VeyraHomeLayout(order: order + rest,
                               hidden: VeyraHomeLayout.defaultOrder.filter { !show.contains($0) },
                               showSport: sport, showShelves: shelves, preset: id)
    }

    static let all: [VeyraHomePreset] = [
        VeyraHomePreset(id: "alles", title: "Alles", detail: "Alle blokken, zoals Veyra standaard is.",
                        symbol: "square.grid.2x2", layout: .standard),
        VeyraHomePreset(id: "filmsSeries", title: "Films en series",
                        detail: "Verder kijken, nieuwe titels, streamingdiensten en collecties. Geen live-tv of sport.",
                        symbol: "film",
                        layout: make("filmsSeries",
                                     order: ["verder", "releasesFilms", "releasesSeries", "volgende", "streaming", "collecties", "vandaag"],
                                     show: ["verder", "releasesFilms", "releasesSeries", "volgende", "streaming", "collecties", "vandaag"],
                                     sport: false)),
        VeyraHomePreset(id: "liveSport", title: "Live-tv en sport",
                        detail: "Live nu, sport en je IPTV-planken. Geen nieuwe releases.",
                        symbol: "sportscourt",
                        layout: make("liveSport",
                                     order: ["live", "vandaag", "iptvFilms", "iptvSeries", "verder", "volgende"],
                                     show: ["live", "vandaag", "iptvFilms", "iptvSeries", "verder", "volgende"],
                                     sport: true)),
        VeyraHomePreset(id: "minimaal", title: "Minimaal",
                        detail: "Alleen Verder kijken en je streamingdiensten.",
                        symbol: "circle.grid.2x1",
                        layout: make("minimaal",
                                     order: ["verder", "volgende", "streaming"],
                                     show: ["verder", "volgende", "streaming"],
                                     sport: false, shelves: false)),
    ]
}

/// Bewaart de indeling. Geen document opgeslagen = de standaardindeling.
nonisolated enum VeyraHomeLayoutStore {
    private static let key = "veyra.home.layout"
    private static let chosenKey = "veyra.home.presetChosen"

    static func load() -> VeyraHomeLayout {
        guard let data = UserDefaults.standard.data(forKey: key),
              let layout = try? JSONDecoder().decode(VeyraHomeLayout.self, from: data) else { return .standard }
        return layout
    }

    static func save(_ layout: VeyraHomeLayout) {
        guard let data = try? JSONEncoder().encode(layout) else { return }
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.set(true, forKey: chosenKey)
        NotificationCenter.default.post(name: .veyraHomeLayoutDidChange, object: nil)
    }

    /// Heeft de gebruiker al een indeling gekozen (of laten synchroniseren)? Anders vragen we het bij de eerste start.
    static var hasChosen: Bool {
        UserDefaults.standard.bool(forKey: chosenKey) || UserDefaults.standard.data(forKey: key) != nil
    }

    static func markChosen() {
        UserDefaults.standard.set(true, forKey: chosenKey)
    }
}

// MARK: - Menu op een blok (lang indrukken)

private struct VeyraHomeTileMenu: ViewModifier {
    let tile: BentoTile

    func body(content: Content) -> some View {
        content.contextMenu {
            Button { update { $0.move(tile, by: -1) } } label: { Label("Blok eerder", systemImage: "arrow.up") }
            Button { update { $0.move(tile, by: 1) } } label: { Label("Blok later", systemImage: "arrow.down") }
            Button(role: .destructive) { update { $0.setVisible(false, tile) } } label: {
                Label("Blok verbergen", systemImage: "eye.slash")
            }
        }
    }

    private func update(_ change: (inout VeyraHomeLayout) -> Void) {
        var layout = VeyraHomeLayoutStore.load()
        change(&layout)
        VeyraHomeLayoutStore.save(layout)
    }
}

extension View {
    /// Lang indrukken op een blok: eerder, later of verbergen.
    func veyraHomeTileMenu(_ tile: BentoTile) -> some View {
        modifier(VeyraHomeTileMenu(tile: tile))
    }
}
