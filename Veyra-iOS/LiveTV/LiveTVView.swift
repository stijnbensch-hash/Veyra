import SwiftUI

struct LiveTVView: View {
    @StateObject
    private var guide = VeyraEPGStore()

    @State
    private var selectedSource: PlayableSource?

    @State
    private var editingLogoChannelID: String?

    @State
    private var editingLogoChannelName = ""

    @State
    private var logoOverrideVersion = 0

    @State
    private var showFavoriteOrder = false

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraColors.background
                    .ignoresSafeArea()

                VStack(
                    spacing: 0
                ) {
                    categorySelector

                    content
                }
            }
            .navigationTitle(
                "Live TV"
            )
            .searchable(
                text:
                    $guide.searchText
            )
            .task(
                id:
                    guide.reloadID
            ) {
                await guide.reload()
            }
            .onReceive(
                NotificationCenter
                    .default
                    .publisher(
                        for:
                            .iptvConfigurationDidChange
                    )
            ) { _ in
                guide.reloadID =
                    UUID()
            }
            .onReceive(
                NotificationCenter
                    .default
                    .publisher(
                        for:
                            .channelOverrideChanged
                    )
            ) { _ in
                logoOverrideVersion += 1
            }
            .navigationDestination(
                item:
                    $selectedSource
            ) { source in
                PlayerView(
                    source:
                        source,
                    item:
                        MediaItem(
                            title:
                                source.name,
                            type:
                                .liveTV
                        )
                )
            }
            .toolbar {
                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {
                    if guide.selectedCategory
                        == "favorites",
                       !guide.favoriteRows.isEmpty
                    {
                        Button {
                            showFavoriteOrder =
                                true

                        } label: {
                            Label(
                                "Ordenen",
                                systemImage:
                                    "line.3.horizontal"
                            )
                        }
                    }
                }
            }
            .sheet(
                isPresented:
                    Binding(
                        get: {
                            editingLogoChannelID
                            != nil
                        },
                        set: {
                            if !$0 {
                                editingLogoChannelID =
                                    nil
                            }
                        }
                    )
            ) {
                if let channelID =
                    editingLogoChannelID
                {
                    ChannelLogoPickerView(
                        channelID:
                            channelID,
                        channelName:
                            editingLogoChannelName,
                        currentOverrideURL:
                            ChannelLogoOverrideStore
                                .logoURL(
                                    forChannelID:
                                        channelID
                                ),
                        currentNameOverride:
                            ChannelNameOverrideStore
                                .name(
                                    forChannelID:
                                        channelID
                                )
                    ) {
                        logoOverrideVersion += 1
                    }
                }
            }
            .sheet(
                isPresented:
                    $showFavoriteOrder
            ) {
                LiveTVFavoritesOrderView(
                    guide:
                        guide
                )
            }
        }
    }

    // MARK: - Category selector

    private var categorySelector: some View {
        Picker(
            "Kanalen",
            selection:
                $guide.selectedCategory
        ) {
            Text(
                "Favorieten"
            )
            .tag(
                "favorites"
            )

            Text(
                "Alle kanalen"
            )
            .tag(
                "all"
            )
        }
        .pickerStyle(
            .segmented
        )
        .padding(
            .horizontal,
            16
        )
        .padding(
            .top,
            8
        )
        .padding(
            .bottom,
            10
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if guide.loadingChannels
            && guide.channels.isEmpty
        {
            Spacer()

            ProgressView(
                "Kanalen laden…"
            )

            Spacer()

        } else if let channelError =
            guide.channelError,
                  guide.channels.isEmpty
        {
            Spacer()

            VStack(
                spacing: 12
            ) {
                Text(
                    "Kanalen konden niet worden geladen"
                )
                .font(
                    .headline
                )

                Text(
                    channelError
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )

                Button(
                    "Opnieuw proberen"
                ) {
                    guide.reloadID =
                        UUID()
                }
            }
            .padding()

            Spacer()

        } else if guide.selectedCategory
            == "favorites"
            && guide.favoriteRows.isEmpty
            && guide.searchText.isEmpty
        {
            favoriteEmptyView

        } else if guide.visibleChannels.isEmpty {
            searchOrChannelEmptyView

        } else {
            channelList
        }
    }

    // MARK: - Channel list

    private var channelList: some View {
        List(
            guide.visibleChannels
        ) { row in
            Button {
                selectedSource =
                    guide.play(
                        row
                    )

            } label: {
                HStack(
                    spacing: 14
                ) {
                    channelLogo(
                        row
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text(
                            ChannelNameOverrideStore
                                .effectiveName(
                                    channelID:
                                        row.channel.id,
                                    defaultName:
                                        row.channel.name
                                )
                        )
                        .foregroundStyle(
                            .primary
                        )
                        .lineLimit(
                            1
                        )

                        if guide.favorites
                            .contains(
                                row.id
                            )
                        {
                            Label(
                                "Favoriet",
                                systemImage:
                                    "star.fill"
                            )
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                VeyraColors.cyan
                            )
                        }
                    }

                    Spacer()

                    Image(
                        systemName:
                            "play.fill"
                    )
                    .foregroundStyle(
                        VeyraColors.cyan
                    )
                }
                .padding(
                    .vertical,
                    6
                )
            }
            .buttonStyle(
                .plain
            )
            .listRowBackground(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(
                    VeyraColors.surface
                )
                .padding(
                    .vertical,
                    3
                )
            )
            .listRowSeparator(
                .hidden
            )
        }
        .listStyle(
            .plain
        )
        .scrollContentBackground(
            .hidden
        )
    }

    // MARK: - Logo

    private func channelLogo(
        _ row: VeyraGuideChannel
    ) -> some View {
        AsyncImage(
            url:
                ChannelLogoOverrideStore
                    .effectiveLogoURL(
                        channelID:
                            row.channel.id,
                        defaultLogoURL:
                            row.channel.logoURL
                    )
        ) { phase in
            switch phase {
            case .success(
                let image
            ):
                image
                    .resizable()
                    .scaledToFit()

            default:
                Image(
                    systemName:
                        "tv"
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .id(
            logoOverrideVersion
        )
        .frame(
            width: 44,
            height: 44
        )
        .contentShape(
            Rectangle()
        )
        .contextMenu {
            channelContextMenu(
                row
            )
        }
    }

    // MARK: - Channel context menu

    @ViewBuilder
    private func channelContextMenu(
        _ row: VeyraGuideChannel
    ) -> some View {
        Button {
            editingLogoChannelID =
                row.channel.id

            editingLogoChannelName =
                row.channel.name

        } label: {
            Label(
                "Logo/naam aanpassen…",
                systemImage:
                    "photo.badge.plus"
            )
        }

        Button {
            guide.toggleFavorite(
                row
            )

        } label: {
            if guide.favorites
                .contains(
                    row.id
                )
            {
                Label(
                    "Uit favorieten verwijderen",
                    systemImage:
                        "star.slash"
                )

            } else {
                Label(
                    "Aan favorieten toevoegen",
                    systemImage:
                        "star"
                )
            }
        }

        if !guide.favoriteRows.isEmpty {
            Button {
                showFavoriteOrder =
                    true

            } label: {
                Label(
                    "Favorieten ordenen…",
                    systemImage:
                        "line.3.horizontal"
                )
            }
        }

        if ChannelLogoOverrideStore
            .logoURL(
                forChannelID:
                    row.channel.id
            )
            != nil
        {
            Button(
                role:
                    .destructive
            ) {
                ChannelLogoOverrideStore
                    .removeOverride(
                        forChannelID:
                            row.channel.id
                    )

                logoOverrideVersion += 1

            } label: {
                Label(
                    "Standaardlogo herstellen",
                    systemImage:
                        "arrow.counterclockwise"
                )
            }
        }
    }

    // MARK: - Empty views

    private var favoriteEmptyView: some View {
        ContentUnavailableView {
            Label(
                "Geen favorieten",
                systemImage:
                    "star"
            )

        } description: {
            Text(
                "Ga naar Alle kanalen en houd een zenderlogo ingedrukt om de zender aan Favorieten toe te voegen."
            )

        } actions: {
            Button(
                "Alle kanalen"
            ) {
                guide.selectedCategory =
                    "all"
            }
        }
    }

    private var searchOrChannelEmptyView: some View {
        Group {
            if !guide.searchText.isEmpty {
                ContentUnavailableView.search(
                    text:
                        guide.searchText
                )

            } else {
                ContentUnavailableView(
                    "Geen kanalen beschikbaar",
                    systemImage:
                        "antenna.radiowaves.left.and.right",
                    description:
                        Text(
                            "Voeg een IPTV-provider toe via Instellingen."
                        )
                )
            }
        }
    }
}
