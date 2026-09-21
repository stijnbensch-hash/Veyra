import SwiftUI

@MainActor
struct LiveTVFavoritesOrderView: View {
    @ObservedObject var guide: VeyraEPGStore

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            Group {
                if guide.favoriteRows.isEmpty {
                    emptyView
                } else {
                    favoritesList
                }
            }
            .navigationTitle("Favorieten ordenen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {
                    Button("Gereed") {
                        dismiss()
                    }
                }
            }
            .environment(
                \.editMode,
                $editMode
            )
        }
    }

    private var favoritesList: some View {
        List {
            ForEach(
                guide.favoriteRows
            ) { row in
                channelRow(
                    row
                )
            }
            .onMove {
                source,
                destination
                in

                guide.moveFavorites(
                    fromOffsets:
                        source,
                    toOffset:
                        destination
                )
            }
        }
    }

    private func channelRow(
        _ row:
            VeyraGuideChannel
    ) -> some View {
        HStack(
            spacing: 14
        ) {
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
                if let image =
                    phase.image
                {
                    image
                        .resizable()
                        .scaledToFit()

                } else {
                    Image(
                        systemName:
                            "tv"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .frame(
                width: 48,
                height: 40
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    3
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
                .font(
                    .body
                        .weight(
                            .semibold
                        )
                )
                .lineLimit(
                    1
                )

                Text(
                    "Favoriet"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()
        }
        .padding(
            .vertical,
            4
        )
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "Geen favorieten",
            systemImage:
                "star",
            description:
                Text(
                    "Voeg eerst zenders toe aan je favorieten."
                )
        )
    }
}
