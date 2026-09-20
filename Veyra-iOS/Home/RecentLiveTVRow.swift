import SwiftUI

/// "Recent bekeken zenders" op de iOS Home-tab. Gebruikt dezelfde
/// gedeelde `VeyraEPGStore` (met schijf-cache) als de Live TV-tab, maar
/// toont een eenvoudige rij zonder de tvOS-programmagids.
struct RecentLiveTVRow: View {
    @StateObject private var guide = VeyraEPGStore()
    @State private var selectedSource: PlayableSource?

    private var recentChannels: [VeyraGuideChannel] {
        let order = Dictionary(
            uniqueKeysWithValues: guide.recent.enumerated().map { ($1, $0) }
        )

        return Array(
            guide.channels
                .filter { order[$0.id] != nil }
                .sorted { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
                .prefix(10)
        )
    }

    var body: some View {
        Group {
            if !recentChannels.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    VeyraSectionHeader(title: "Recent bekeken zenders")
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(recentChannels) { row in
                                Button {
                                    selectedSource = guide.play(row)
                                } label: {
                                    channelTile(row)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .task {
            await guide.reload()
        }
        .navigationDestination(item: $selectedSource) { source in
            PlayerView(
                source: source,
                item: MediaItem(title: source.name, type: .liveTV)
            )
        }
    }

    private func channelTile(_ row: VeyraGuideChannel) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(VeyraColors.surface)

                AsyncImage(url: row.channel.logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit().padding(10)
                    default:
                        Image(systemName: "tv")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 120, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(row.channel.name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 120)
                .foregroundStyle(.primary)
        }
    }
}
