import SwiftUI

struct LiveTVView: View {
    @StateObject private var guide = VeyraEPGStore()
    @State private var selectedSource: PlayableSource?

    // Logo aanpassen: lang drukken op een zenderlogo opent
    // `ChannelLogoPickerView`. `logoOverrideVersion` dwingt de betrokken
    // AsyncImage opnieuw te laden zodra een override is opgeslagen.
    @State private var editingLogoChannelID: String?
    @State private var editingLogoChannelName = ""
    @State private var logoOverrideVersion = 0

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
            .onReceive(NotificationCenter.default.publisher(for: .channelOverrideChanged)) { _ in
                logoOverrideVersion += 1
            }
            .navigationDestination(item: $selectedSource) { source in
                PlayerView(
                    source: source,
                    item: MediaItem(title: source.name, type: .liveTV)
                )
            }
            .sheet(
                isPresented: Binding(
                    get: { editingLogoChannelID != nil },
                    set: { if !$0 { editingLogoChannelID = nil } }
                )
            ) {
                if let channelID = editingLogoChannelID {
                    ChannelLogoPickerView(
                        channelID: channelID,
                        channelName: editingLogoChannelName,
                        currentOverrideURL: ChannelLogoOverrideStore.logoURL(forChannelID: channelID),
                        currentNameOverride: ChannelNameOverrideStore.name(forChannelID: channelID)
                    ) {
                        logoOverrideVersion += 1
                    }
                }
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
                        AsyncImage(
                            url: ChannelLogoOverrideStore.effectiveLogoURL(
                                channelID: row.channel.id, defaultLogoURL: row.channel.logoURL
                            )
                        ) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            default:
                                Image(systemName: "tv").foregroundStyle(.secondary)
                            }
                        }
                        .id(logoOverrideVersion)
                        .frame(width: 44, height: 44)
                        .contextMenu {
                            Button {
                                editingLogoChannelID = row.channel.id
                                editingLogoChannelName = row.channel.name
                            } label: {
                                Label("Logo/naam aanpassen…", systemImage: "photo.badge.plus")
                            }

                            if ChannelLogoOverrideStore.logoURL(forChannelID: row.channel.id) != nil {
                                Button(role: .destructive) {
                                    ChannelLogoOverrideStore.removeOverride(forChannelID: row.channel.id)
                                    logoOverrideVersion += 1
                                } label: {
                                    Label("Standaardlogo herstellen", systemImage: "arrow.counterclockwise")
                                }
                            }
                        }

                        Text(
                            ChannelNameOverrideStore.effectiveName(
                                channelID: row.channel.id, defaultName: row.channel.name
                            )
                        )
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
