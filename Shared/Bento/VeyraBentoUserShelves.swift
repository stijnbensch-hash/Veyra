// VeyraBentoUserShelves.swift
// De eigen planken uit Instellingen > Planken (Trakt-, TMDB- of addon-lijsten) als extra kaders onder de bento-home.

import SwiftUI

struct VeyraBentoUserShelves: View {
    var compact = false
    var onOpen: (BentoTMDBTitle) -> Void = { _ in }

    @State private var shelves: [Shelf] = []

    var body: some View {
        // .task/.onReceive staan op de container, niet op de ForEach (die is bij de eerste render nog leeg).
        VStack(alignment: .leading, spacing: compact ? 12 : 24) {
            ForEach(shelves) { shelf in
                VeyraBentoUserShelf(shelf: shelf, compact: compact, onOpen: onOpen)
            }
        }
        .task { shelves = ShelfStore().enabledShelves() }
        .onReceive(NotificationCenter.default.publisher(for: .veyraShelfConfigurationDidChange)) { _ in
            shelves = ShelfStore().enabledShelves()
        }
    }
}

private struct VeyraBentoUserShelf: View {
    let shelf: Shelf
    let compact: Bool
    let onOpen: (BentoTMDBTitle) -> Void

    @State private var titles: [BentoTMDBTitle] = []
    @State private var loaded = false

    var body: some View {
        Group {
            if !loaded || !titles.isEmpty {
                VeyraBentoShelf(title: shelf.title, subtitle: shelf.source.subtitle, compact: compact) {
                    ForEach(titles) { title in card(title) }
                }
                .frame(height: compact ? 270 : 440)
            }
        }
        .task(id: shelf.id) { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .veyraShelfConfigurationDidChange)) { _ in
            Task { await load() }
        }
    }

    @ViewBuilder
    private func card(_ title: BentoTMDBTitle) -> some View {
        #if os(tvOS)
        Button { onOpen(title) } label: {
            VeyraBentoPosterContent(title: title.title, url: title.posterURL, compact: compact, watchedID: title.id, watchedKind: title.kind)
        }
        .buttonStyle(VeyraPosterFocusStyle())
        #else
        Button { onOpen(title) } label: {
            VeyraBentoPosterContent(title: title.title, url: title.posterURL, compact: compact, watchedID: title.id, watchedKind: title.kind)
        }
        .buttonStyle(.plain)
        #endif
    }

    private func load() async {
        let items = await ShelfCatalogService.items(for: shelf)
        var result: [BentoTMDBTitle] = []
        for item in items {
            guard let id = item.tmdbID, item.type == .movie || item.type == .series else { continue }
            result.append(BentoTMDBTitle(id: id, kind: item.type == .movie ? .movie : .episode,
                                         title: item.title, posterURL: item.posterURL))
        }
        titles = result
        loaded = true
    }
}
