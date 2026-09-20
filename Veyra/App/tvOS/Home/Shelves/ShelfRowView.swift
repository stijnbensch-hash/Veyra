import SwiftUI

/// Eén door de gebruiker ingestelde plank op de tvOS Home, in dezelfde stijl
/// als de bestaande rijen (Trakt, IPTV, Jellyfin, "Populaire films").
struct ShelfRowView: View {
    let shelf: Shelf

    @State private var items: [MediaItem] = []

    var body: some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    VeyraSectionHeader(title: shelf.title, subtitle: shelf.source.subtitle)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: VeyraSpacing.rail) {
                            ForEach(items) { item in
                                NavigationLink { ShelfItemDestination(item: item) } label: {
                                    VeyraPosterCard(
                                        title: item.title,
                                        url: item.posterURL,
                                        symbol: item.type == .movie ? "film" : "tv",
                                        width: 220
                                    )
                                }
                                .buttonStyle(VeyraFocusButtonStyle(radius: VeyraRadius.poster))
                                .reportsHero(.mediaItem(item))
                            }
                        }.padding(12)
                    }.scrollClipDisabled()
                }
            }
        }
        .task(id: shelf.id) { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .veyraShelfConfigurationDidChange)) { _ in
            Task { await load() }
        }
    }

    private func load() async {
        items = await ShelfCatalogService.items(for: shelf)
    }
}

/// Alle ingeschakelde planken, in de door de gebruiker ingestelde volgorde.
struct ShelvesHomeSection: View {
    @State private var shelves: [Shelf] = []

    var body: some View {
        // Belangrijk: .task/.onReceive worden hier op een Group gezet, niet
        // rechtstreeks op de ForEach. Modifiers op een ForEach worden verdeeld
        // over de gegenereerde subviews; zolang `shelves` leeg is (altijd het
        // geval bij de eerste render) bestaat er geen subview om ze aan te
        // hechten, dus zonder deze Group zou reload() nooit aangeroepen worden
        // en zouden planken nooit verschijnen.
        Group {
            ForEach(shelves) { shelf in
                ShelfRowView(shelf: shelf)
            }
        }
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .veyraShelfConfigurationDidChange)) { _ in reload() }
    }

    private func reload() {
        shelves = ShelfStore().enabledShelves()
    }
}

extension VeyraHeroContent {
    static func mediaItem(_ item: MediaItem) -> VeyraHeroContent {
        VeyraHeroContent(
            id: "shelf:\(item.id)",
            eyebrow: item.type == .movie ? "Uitgelicht" : "Serie uitgelicht",
            title: item.title,
            overview: item.overview,
            metadata: item.releaseDate.map { [String($0.prefix(4))] } ?? [],
            backdropURL: item.backdropURL
        )
    }
}
