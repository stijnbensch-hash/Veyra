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

    // Planken kunnen ook niet-TMDB-items bevatten (bv. IPTV-films/series uit
    // een gekozen categorie) — daarom hier `MediaItem`s i.p.v. alleen
    // `BentoTMDBTitle`, zodat zulke items niet stilletjes wegvallen.
    @State private var items: [MediaItem] = []
    @State private var loaded = false

    var body: some View {
        Group {
            if !loaded || !items.isEmpty {
                VeyraBentoShelf(title: shelf.title, subtitle: shelf.source.subtitle, compact: compact) {
                    ForEach(items) { item in card(item) }
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
    private func card(_ item: MediaItem) -> some View {
        if let tmdbID = item.tmdbID, item.type == .movie || item.type == .series {
            let kind: MediaKind = item.type == .movie ? .movie : .episode
            #if os(tvOS)
            Button {
                onOpen(BentoTMDBTitle(id: tmdbID, kind: kind, title: item.title, posterURL: item.posterURL))
            } label: {
                VeyraBentoPosterContent(title: item.title, url: item.posterURL, compact: compact, watchedID: tmdbID, watchedKind: kind)
            }
            .buttonStyle(VeyraPosterFocusStyle())
            #else
            Button {
                onOpen(BentoTMDBTitle(id: tmdbID, kind: kind, title: item.title, posterURL: item.posterURL))
            } label: {
                VeyraBentoPosterContent(title: item.title, url: item.posterURL, compact: compact, watchedID: tmdbID, watchedKind: kind)
            }
            .buttonStyle(.plain)
            #endif
        } else {
            // Geen TMDB-titel (bv. IPTV) — zelfde generieke doorverwijzing als
            // de andere planken-rijen (`ShelfRowView`) gebruiken.
            #if os(tvOS)
            NavigationLink { ShelfItemDestination(item: item) } label: {
                VeyraBentoPosterContent(title: item.title, url: item.posterURL, compact: compact)
            }
            .buttonStyle(VeyraPosterFocusStyle())
            #else
            NavigationLink { ShelfItemDestination(item: item) } label: {
                VeyraBentoPosterContent(title: item.title, url: item.posterURL, compact: compact)
            }
            .buttonStyle(.plain)
            #endif
        }
    }

    private func load() async {
        items = await ShelfCatalogService.items(for: shelf)
        loaded = true
    }
}
