import SwiftUI

struct LiveTVView: View {
    @StateObject private var guide = VeyraEPGStore()
    @State private var selectedSource: PlayableSource?

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraColors.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Live TV")
            .searchable(text: $guide.searchText)
            .task(id: guide.reloadID) { await guide.reload() }
            .onReceive(NotificationCenter.default.publisher(for: .iptvConfigurationDidChange)) { _ in
                guide.reloadID = UUID()
            }
            .navigationDestination(item: $selectedSource) { source in
                PlayerView(
                    source: source,
                    item: MediaItem(title: source.name, type: .liveTV)
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if guide.loadingChannels && guide.visibleChannels.isEmpty {
            ProgressView("Kanalen laden…")
        } else if let channelError = guide.channelError, guide.visibleChannels.isEmpty {
            VStack(spacing: 12) {
                Text("Kanalen konden niet worden geladen").font(.headline)
                Text(channelError).font(.subheadline).foregroundStyle(.secondary)
                Button("Opnieuw proberen") { guide.reloadID = UUID() }
            }
            .padding()
        } else if guide.visibleChannels.isEmpty {
            ContentUnavailableView(
                "Geen kanalen beschikbaar",
                systemImage: "antenna.radiowaves.left.and.right",
                description: Text("Voeg een IPTV-provider toe via Instellingen.")
            )
        } else {
            List(guide.visibleChannels) { row in
                Button {
                    selectedSource = guide.play(row)
                } label: {
                    HStack(spacing: 14) {
                        AsyncImage(url: row.channel.logoURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            default:
                                Image(systemName: "tv").foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 44, height: 44)

                        Text(row.channel.name)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "play.fill")
                            .foregroundStyle(VeyraColors.cyan)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VeyraColors.surface)
                        .padding(.vertical, 3)
                )
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}
