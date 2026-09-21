import SwiftUI

/// Home-rij met onlangs toegevoegde titels van alle gekoppelde
/// mediaservers (Jellyfin). Toont zichzelf niet als er geen server
/// gekoppeld is of er niets te tonen valt.
struct JellyfinRecentlyAddedRow: View {
    private struct Entry: Identifiable, Hashable {
        let account: MediaServerAccount
        let item: JellyfinItem

        var id: String {
            "\(account.id)-\(item.id)"
        }
    }

    @State private var entries: [Entry] = []
    @State private var hasServers = false

    private let posterWidth: CGFloat = 230

    private let store = MediaServerStore()

    var body: some View {
        Group {
            if hasServers && !entries.isEmpty {
                VStack(alignment: .leading, spacing: 18) {
                    VeyraSectionHeader(
                        title: "Onlangs toegevoegd op je mediaserver",
                        subtitle: "Jellyfin"
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: VeyraSpacing.rail) {
                            ForEach(entries) { entry in
                                entryLink(entry)
                            }
                        }
                        .padding(12)
                    }
                    .scrollClipDisabled()
                }
            }
        }
        .task {
            await load()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .veyraMediaServerConfigurationDidChange
            )
        ) { _ in
            Task { await load() }
        }
    }

    private func entryLink(_ entry: Entry) -> some View {
        let imageURL = JellyfinService(account: entry.account).imageURL(for: entry.item)

        return NavigationLink {
            JellyfinPlaybackDestination(account: entry.account, item: entry.item)
        } label: {
            VeyraPosterCard(
                title: entry.item.displayTitle,
                url: imageURL,
                symbol: entry.item.isEpisode ? "tv" : "film",
                width: posterWidth,
                genre: entry.item.primaryGenre,
                rating: entry.item.communityRating
            )
        }
        .buttonStyle(VeyraFocusButtonStyle(radius: VeyraRadius.poster))
        .reportsHero(
            VeyraHeroContent(
                id: "jellyfin:\(entry.id)",
                eyebrow: entry.item.isEpisode ? "Serie" : "Film",
                title: entry.item.displayTitle,
                overview: nil,
                metadata: [],
                backdropURL: imageURL
            )
        )
    }

    private func load() async {
        let accounts =
            store.load().filter { $0.kind == .jellyfin }

        hasServers = !accounts.isEmpty

        guard !accounts.isEmpty else {
            entries = []
            return
        }

        var result: [Entry] = []

        for account in accounts {
            do {
                let items =
                    try await JellyfinService(account: account)
                        .recentlyAdded(limit: 20)

                result.append(
                    contentsOf: items.map { Entry(account: account, item: $0) }
                )
            } catch {
                continue
            }
        }

        entries = result
    }
}
