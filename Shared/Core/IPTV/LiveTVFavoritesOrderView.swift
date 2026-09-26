import SwiftUI

@MainActor
struct LiveTVFavoritesOrderView:
    View
{
    @ObservedObject
    var guide:
        VeyraEPGStore

    @Environment(
        \.dismiss
    )
    private var dismiss

    var body:
        some View
    {
        #if os(tvOS)

        tvOSView

        #else

        iOSView

        #endif
    }

    // MARK: - Shared logo

    private func channelLogo(
        _ row:
            VeyraGuideChannel,
        width:
            CGFloat,
        height:
            CGFloat
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
        ) {
            phase in

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
        .frame(
            width:
                width,
            height:
                height
        )
    }

    // MARK: - iOS

    #if !os(tvOS)

    private var iOSView:
        some View
    {
        NavigationStack {
            Group {
                if guide
                    .favoriteRows
                    .isEmpty
                {
                    ContentUnavailableView(
                        "Geen favorieten",
                        systemImage:
                            "star",
                        description:
                            Text(
                                "Voeg eerst zenders toe aan je favorieten."
                            )
                    )

                } else {
                    List {
                        ForEach(
                            guide.favoriteRows
                        ) {
                            row in

                            iOSFavoriteRow(
                                row
                            )
                        }
                        .onMove {
                            source,
                            destination
                            in

                            moveFavorites(
                                from:
                                    source,
                                to:
                                    destination
                            )
                        }
                    }
                }
            }
            .navigationTitle(
                "Favorieten ordenen"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .veyraAlwaysEditing()
            .toolbar {
                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {
                    Button(
                        "Gereed"
                    ) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func iOSFavoriteRow(
        _ row:
            VeyraGuideChannel
    ) -> some View {
        HStack(
            spacing:
                14
        ) {
            channelLogo(
                row,
                width:
                    48,
                height:
                    42
            )

            Text(
                ChannelNameOverrideStore
                    .effectiveName(
                        channelID:
                            row.channel.id,
                        defaultName:
                            row.channel.name
                    )
            )
            .lineLimit(
                1
            )

            Spacer()

            Image(
                systemName:
                    "line.3.horizontal"
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(
            .vertical,
            4
        )
    }

    private func moveFavorites(
        from source:
            IndexSet,
        to destination:
            Int
    ) {
        var rows =
            guide.favoriteRows

        rows.move(
            fromOffsets:
                source,
            toOffset:
                destination
        )

        guide
            .setFavoriteOrder(
                rows.map(
                    \.id
                )
            )
    }

    #endif

    // MARK: - tvOS

    #if os(tvOS)

    private var tvOSView:
        some View
    {
        ZStack {
            VeyraBackground()
                .ignoresSafeArea()

            VStack(
                alignment:
                    .leading,
                spacing:
                    28
            ) {
                header

                if guide
                    .favoriteRows
                    .isEmpty
                {
                    tvOSEmptyView

                } else {
                    tvOSList
                }
            }
            .padding(
                58
            )
        }
        .foregroundStyle(
            .white
        )
    }

    private var header:
        some View
    {
        HStack(
            spacing:
                24
        ) {
            RoundedRectangle(
                cornerRadius:
                    3
            )
            .fill(
                Color.cyan
            )
            .frame(
                width:
                    6,
                height:
                    56
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    6
            ) {
                Text(
                    "FAVORIETEN ORDENEN"
                )
                .font(
                    .system(
                        size:
                            40,
                        weight:
                            .light
                    )
                )
                .tracking(
                    4
                )

                Text(
                    "WIJZIG DE VOLGORDE VAN JE ZENDERS"
                )
                .font(
                    .system(
                        size:
                            16,
                        weight:
                            .medium
                    )
                )
                .tracking(
                    2
                )
                .foregroundStyle(
                    .cyan.opacity(
                        0.75
                    )
                )
            }

            Spacer()

            Button {
                dismiss()

            } label: {
                Image(
                    systemName:
                        "xmark"
                )
                .font(
                    .system(
                        size:
                            25,
                        weight:
                            .semibold
                    )
                )
                .frame(
                    width:
                        66,
                    height:
                        66
                )
            }
            .buttonStyle(
                FavoriteOrderTVButtonStyle()
            )
        }
    }

    private var tvOSList:
        some View
    {
        ScrollView(
            .vertical,
            showsIndicators:
                false
        ) {
            LazyVStack(
                spacing:
                    14
            ) {
                ForEach(
                    Array(
                        guide
                            .favoriteRows
                            .enumerated()
                    ),
                    id:
                        \.element.id
                ) {
                    index,
                    row
                    in

                    tvOSFavoriteRow(
                        row,
                        position:
                            index
                            + 1
                    )
                }
            }
            .padding(
                .vertical,
                4
            )
        }
    }

    private func tvOSFavoriteRow(
        _ row:
            VeyraGuideChannel,
        position:
            Int
    ) -> some View {
        HStack(
            spacing:
                20
        ) {
            Text(
                "\(position)"
            )
            .font(
                .system(
                    size:
                        21,
                    weight:
                        .semibold
                )
            )
            .foregroundStyle(
                .cyan
            )
            .frame(
                width:
                    44
            )

            channelLogo(
                row,
                width:
                    76,
                height:
                    60
            )

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
                .system(
                    size:
                        24,
                    weight:
                        .semibold
                )
            )
            .lineLimit(
                1
            )

            Spacer(
                minLength:
                    30
            )

            Button {
                guide
                    .moveFavoriteToTop(
                        row
                    )

            } label: {
                Image(
                    systemName:
                        "arrow.up.to.line"
                )
                .frame(
                    width:
                        60,
                    height:
                        60
                )
            }
            .buttonStyle(
                FavoriteOrderTVButtonStyle()
            )
            .disabled(
                !guide
                    .canMoveFavoriteUp(
                        row
                    )
            )

            Button {
                guide
                    .moveFavoriteUp(
                        row
                    )

            } label: {
                Image(
                    systemName:
                        "chevron.up"
                )
                .frame(
                    width:
                        60,
                    height:
                        60
                )
            }
            .buttonStyle(
                FavoriteOrderTVButtonStyle()
            )
            .disabled(
                !guide
                    .canMoveFavoriteUp(
                        row
                    )
            )

            Button {
                guide
                    .moveFavoriteDown(
                        row
                    )

            } label: {
                Image(
                    systemName:
                        "chevron.down"
                )
                .frame(
                    width:
                        60,
                    height:
                        60
                )
            }
            .buttonStyle(
                FavoriteOrderTVButtonStyle()
            )
            .disabled(
                !guide
                    .canMoveFavoriteDown(
                        row
                    )
            )

            Button {
                guide
                    .moveFavoriteToBottom(
                        row
                    )

            } label: {
                Image(
                    systemName:
                        "arrow.down.to.line"
                )
                .frame(
                    width:
                        60,
                    height:
                        60
                )
            }
            .buttonStyle(
                FavoriteOrderTVButtonStyle()
            )
            .disabled(
                !guide
                    .canMoveFavoriteDown(
                        row
                    )
            )
        }
        .padding(
            .horizontal,
            20
        )
        .padding(
            .vertical,
            14
        )
        .background(
            RoundedRectangle(
                cornerRadius:
                    16,
                style:
                    .continuous
            )
            .fill(
                Color(
                    red:
                        0.035,
                    green:
                        0.10,
                    blue:
                        0.16
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius:
                    16,
                style:
                    .continuous
            )
            .strokeBorder(
                Color.cyan
                    .opacity(
                        0.12
                    ),
                lineWidth:
                    1
            )
        )
    }

    private var tvOSEmptyView:
        some View
    {
        VStack(
            spacing:
                18
        ) {
            Image(
                systemName:
                    "star"
            )
            .font(
                .system(
                    size:
                        50
                )
            )
            .foregroundStyle(
                .cyan.opacity(
                    0.65
                )
            )

            Text(
                "Nog geen favorieten"
            )
            .font(
                .system(
                    size:
                        28,
                    weight:
                        .semibold
                )
            )

            Text(
                "Voeg eerst zenders toe aan Favorieten."
            )
            .font(
                .system(
                    size:
                        20
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }

    #endif
}


// MARK: - tvOS button

#if os(tvOS)

private struct FavoriteOrderTVButtonStyle:
    ButtonStyle
{
    func makeBody(
        configuration:
            Configuration
    ) -> some View {
        FavoriteOrderTVButtonSurface(
            label:
                configuration.label,
            pressed:
                configuration
                    .isPressed
        )
    }
}

private struct FavoriteOrderTVButtonSurface<
    Label:
        View
>:
    View
{
    let label:
        Label

    let pressed:
        Bool

    @Environment(
        \.isFocused
    )
    private var isFocused

    @Environment(
        \.isEnabled
    )
    private var isEnabled

    var body:
        some View
    {
        label
            .foregroundStyle(
                .white
            )
            .background(
                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                        .continuous
                )
                .fill(
                    isFocused
                    ?
                    Color.cyan
                        .opacity(
                            0.30
                        )
                    :
                    Color(
                        red:
                            0.035,
                        green:
                            0.10,
                        blue:
                            0.16
                    )
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                        .continuous
                )
                .strokeBorder(
                    isFocused
                    ?
                    Color.cyan
                    :
                    Color.cyan
                        .opacity(
                            0.12
                        ),
                    lineWidth:
                        isFocused
                        ?
                        2
                        :
                        1
                )
            )
            .scaleEffect(
                isFocused
                ?
                1.035
                :
                1
            )
            .opacity(
                !isEnabled
                ?
                0.35
                :
                pressed
                ?
                0.8
                :
                1
            )
            .animation(
                .easeOut(
                    duration:
                        0.12
                ),
                value:
                    isFocused
            )
    }
}

#endif
