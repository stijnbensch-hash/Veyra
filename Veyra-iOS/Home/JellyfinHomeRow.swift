import SwiftUI

/// iOS-native "Onlangs toegevoegd op je mediaserver" (Jellyfin) rij voor Home.
/// Hergebruikt dezelfde Shared MediaServer/Jellyfin-laag als de tvOS-versie
/// (`JellyfinRecentlyAddedRow`), maar met platte iOS-navigatie i.p.v. focus-styling.
struct JellyfinHomeRow: View {
    private struct Entry: Identifiable, Hashable {
        let account: MediaServerAccount
        let item: JellyfinItem
        var id: String { "\(account.id)-\(item.id)" }
    }

    @State private var entries: [Entry] = []
    @State private var hasServers = false
    private let posterWidth: CGFloat = 130
    private let store = MediaServerStore()

    var body: some View {
        Group {
            if hasServers && !entries.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    VeyraSectionHeader(title: "Onlangs toegevoegd op je mediaserver", subtitle: "Jellyfin")
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: VeyraSpacing.rail) {
                            ForEach(entries) { entry in
                                entryLink(entry)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .veyraMediaServerConfigurationDidChange)) { _ in
            Task { await load() }
        }
    }

    private func entryLink(_ entry: Entry) -> some View {
        NavigationLink {
            JellyfinHomePlaybackDestination(account: entry.account, item: entry.item)
        } label: {
            VeyraPosterCard(
                title: entry.item.displayTitle,
                url: JellyfinService(account: entry.account).imageURL(for: entry.item),
                symbol: entry.item.isEpisode ? "tv" : "film",
                width: posterWidth,
                genre: entry.item.primaryGenre,
                rating: entry.item.communityRating
            )
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        let accounts = store.load().filter { $0.kind == .jellyfin }
        hasServers = !accounts.isEmpty
        guard !accounts.isEmpty else { entries = []; return }

        var result: [Entry] = []
        for account in accounts {
            do {
                let items = try await JellyfinService(account: account).recentlyAdded(limit: 20)
                result.append(contentsOf: items.map { Entry(account: account, item: $0) })
            } catch {
                continue
            }
        }
        entries = result
    }
}

/// iOS-equivalent van tvOS' `JellyfinPlaybackDestination`: bouwt een
/// afspeelbare bron op voor een Jellyfin-item en speelt af via de iOS `PlayerView`.
private struct JellyfinHomePlaybackDestination: View {
    let account: MediaServerAccount
    let item: JellyfinItem

    var body: some View {
        Group {
            if let url = JellyfinService(account: account).streamURL(for: item) {
                PlayerView(
                    source: PlayableSource(
                        name: item.displayTitle,
                        description: item.overview,
                        url: url,
                        kind: .direct,
                        providerName: account.name
                    ),
                    item: mediaItem
                )
            } else {
                VStack(spacing: 20) {
                    Text("Afspelen niet mogelijk")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Kon geen afspeel-URL opbouwen voor deze titel.")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VeyraBackground())
            }
        }
    }

    private var mediaItem: MediaItem {
        MediaItem(
            title: item.isEpisode ? (item.seriesName ?? item.name) : item.name,
            type: item.isEpisode ? .series : .movie,
            seasonNumber: item.parentIndexNumber,
            episodeNumber: item.indexNumber,
            overview: item.overview,
            releaseDate: item.productionYear.map { String($0) }
        )
    }
}
