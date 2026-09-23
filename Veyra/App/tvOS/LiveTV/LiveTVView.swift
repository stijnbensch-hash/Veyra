import SwiftUI
import Foundation

@MainActor
struct LiveTVView: View {
    @StateObject
    private var guide = VeyraEPGStore()

    @State
    private var showProviders = false

    @State
    private var showSearch = false

    @State
    private var showFavoriteOrder = false

    @State
    private var selection: VeyraEPGSelection?

    @State
    private var selectedSource: PlayableSource?

    @State
    private var pendingSource: PlayableSource?

    @State
    private var editingLogoChannel: IPTVChannel?

    @State
    private var logoOverrideVersion = 0

    @Environment(\.scenePhase)
    private var scenePhase

    var body: some View {
        navigationLayer
    }

    // MARK: - Root layers

    private var navigationLayer: some View {
        sheetLayer
            .navigationDestination(
                item: $selectedSource
            ) { source in
                PlayerView(
                    source: source,
                    item: MediaItem(
                        title: source.name,
                        type: .liveTV
                    )
                )
            }
    }

    private var sheetLayer: some View {
        providerDialogLayer
            .sheet(
                item: $selection,
                onDismiss: handleSelectionDismiss
            ) { selected in
                VeyraEPGDetails(
                    selection: selected,
                    guide: guide,
                    onPlay: {
                        startLivePlayback(
                            selected
                        )
                    }
                )
            }
            .sheet(
                item: $editingLogoChannel
            ) { channel in
                ChannelLogoPickerView(
                    channelID: channel.id,
                    channelName: channel.name,
                    currentOverrideURL:
                        ChannelLogoOverrideStore.logoURL(
                            forChannelID: channel.id
                        ),
                    currentNameOverride:
                        ChannelNameOverrideStore.name(
                            forChannelID: channel.id
                        )
                ) {
                    logoOverrideVersion += 1
                }
            }
            .sheet(
                isPresented: $showSearch
            ) {
                LiveTVSearchView(
                    searchText:
                        $guide.searchText
                )
            }
            .sheet(
                isPresented: $showFavoriteOrder
            ) {
                LiveTVFavoritesOrderView(
                    guide: guide
                )
            }
    }

    private var providerDialogLayer: some View {
        lifecycleLayer
            .confirmationDialog(
                "Kies je IPTV-provider",
                isPresented: $showProviders,
                titleVisibility: .visible
            ) {
                providerDialogButtons
            }
    }

    private var lifecycleLayer: some View {
        mainLayout
            .foregroundStyle(.white)
            .task(
                id: guide.reloadID
            ) {
                await guide.reload()
            }
            .onReceive(
                Timer.publish(every: 1_800, on: .main, in: .common).autoconnect()
            ) { _ in
                guide.reloadID = UUID()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .iptvConfigurationDidChange
                )
            ) { _ in
                handleIPTVConfigurationChange()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .channelOverrideChanged
                )
            ) { _ in
                logoOverrideVersion += 1
            }
            .onChange(
                of: scenePhase
            ) { phase in
                handleScenePhase(
                    phase
                )
            }
    }

    // MARK: - Main layout

    private var mainLayout: some View {
        ZStack {
            VeyraEPGTheme.background
                .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                toolbar

                channelErrorView

                guideLayout

                footer
            }
            .padding(
                .horizontal,
                50
            )
            .padding(
                .vertical,
                32
            )
        }
    }

    @ViewBuilder
    private var channelErrorView: some View {
        if let error =
            guide.channelError
        {
            Text(
                error
            )
            .font(
                .system(
                    size: 18
                )
            )
            .foregroundStyle(
                .orange
            )
        }
    }

    // MARK: - Lifecycle

    private func handleIPTVConfigurationChange() {
        selection = nil
        guide.reloadID = UUID()
    }

    private func handleScenePhase(
        _ phase: ScenePhase
    ) {
        if phase == .active {
            guide.reloadID = UUID()
        }
    }

    private func handleSelectionDismiss() {
        guard
            let source = pendingSource
        else {
            return
        }

        pendingSource = nil
        selectedSource = source
    }

    private func startLivePlayback(
        _ selected: VeyraEPGSelection
    ) {
        let directSource = guide.play(selected.row)
        Task {
            pendingSource = await VeyraLocalLiveFallback.shared.source(
                for: selected.row.channel,
                original: directSource
            )
            selection = nil
        }
    }

    // MARK: - Provider dialog

    @ViewBuilder
    private var providerDialogButtons: some View {
        ForEach(
            guide.providers
        ) { provider in
            Button(
                providerTitle(
                    provider
                )
            ) {
                guide.selectProvider(
                    provider
                )
            }
        }

        Button(
            "Annuleren",
            role: .cancel
        ) {}
    }

    private func providerTitle(
        _ provider: IPTVStoredProvider
    ) -> String {
        if provider.id
            == guide.activeProviderID
        {
            return
                provider.displayName
                + " (actief)"
        }

        return provider.displayName
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(
            spacing: 18
        ) {
            toolbarTitle

            Spacer(
                minLength: 10
            )

            providerButton

            nowButton

            searchButton

            refreshButton

            settingsButton
        }
        .font(
            .system(
                size: 18,
                weight: .semibold
            )
        )
        .focusSection()
    }

    private var toolbarTitle: some View {
        HStack(
            spacing: 14
        ) {
            RoundedRectangle(
                cornerRadius: 2
            )
            .fill(
                .cyan
            )
            .frame(
                width: 4,
                height: 38
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(
                    "LIVE TV"
                )
                .font(
                    .system(
                        size: 32,
                        weight: .light
                    )
                )
                .tracking(
                    5
                )

                Text(
                    "JOUW PROGRAMMAGIDS"
                )
                .font(
                    .system(
                        size: 12,
                        weight: .medium
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
        }
    }

    private var providerButton: some View {
        Button {
            showProviders = true

        } label: {
            Label(
                guide.providerName,
                systemImage:
                    "antenna.radiowaves.left.and.right"
            )
            .lineLimit(
                1
            )
            .frame(
                maxWidth: 300
            )
            .padding(
                .horizontal,
                16
            )
            .padding(
                .vertical,
                12
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
        .disabled(
            guide.providers.isEmpty
        )
    }

    private var nowButton: some View {
        Button {
            guide.showNow()

        } label: {
            Label(
                "Nu",
                systemImage:
                    "clock"
            )
            .padding(
                .horizontal,
                16
            )
            .padding(
                .vertical,
                12
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
    }

    private var searchButton: some View {
        Button {
            showSearch = true

        } label: {
            Image(
                systemName:
                    "magnifyingglass"
            )
            .font(
                .system(
                    size: 21,
                    weight: .semibold
                )
            )
            .frame(
                width: 48,
                height: 48
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
        .accessibilityLabel(
            "Zoeken"
        )
    }

    private var refreshButton: some View {
        Button {
            guide.reloadID =
                UUID()

        } label: {
            Image(
                systemName:
                    "arrow.clockwise"
            )
            .frame(
                width: 48,
                height: 48
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
        .accessibilityLabel(
            "Zenders en programmagids vernieuwen"
        )
    }

    private var settingsButton: some View {
        NavigationLink {
            IPTVAccountsView()

        } label: {
            Image(
                systemName:
                    "gearshape"
            )
            .frame(
                width: 48,
                height: 48
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
        .accessibilityLabel(
            "IPTV-providers beheren"
        )
    }

    // MARK: - Layout

    private var guideLayout: some View {
        HStack(
            alignment: .top,
            spacing: 22
        ) {
            sidebar
                .frame(
                    width: 250
                )

            TimelineView(
                .periodic(
                    from: .now,
                    by: 60
                )
            ) { context in
                programmeGrid(
                    now: context.date
                )
            }
            .focusSection()
        }
    }

    // MARK: - Categories

    private var sidebar: some View {
        ScrollView(
            .vertical,
            showsIndicators: false
        ) {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                categoryButton(
                    "Alle zenders",
                    icon: "tv",
                    key: "all",
                    count:
                        guide.channels.count
                )

                categoryButton(
                    "Favorieten",
                    icon: "star",
                    key: "favorites",
                    count:
                        guide.favoriteRows.count
                )

                categoryButton(
                    "Recent geopend",
                    icon:
                        "clock.arrow.circlepath",
                    key: "recent",
                    count:
                        recentCount
                )

                Text(
                    "CATEGORIEËN"
                )
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .tracking(
                    2
                )
                .foregroundStyle(
                    .cyan.opacity(
                        0.6
                    )
                )
                .padding(
                    .top,
                    18
                )
                .padding(
                    .bottom,
                    6
                )

                ForEach(
                    guide.categories
                ) { category in
                    categoryButton(
                        category.name,
                        icon: nil,
                        key:
                            "group:"
                            + category.id,
                        count: nil
                    )
                }
            }
            .padding(
                4
            )
        }
        .focusSection()
    }

    private var recentCount: Int {
        guide.channels.filter {
            guide.recent.contains(
                $0.id
            )
        }
        .count
    }

    private func categoryButton(
        _ title: String,
        icon: String?,
        key: String,
        count: Int?
    ) -> some View {
        Button {
            guide.selectedCategory =
                key

        } label: {
            HStack(
                spacing: 10
            ) {
                if let icon {
                    Image(
                        systemName:
                            icon
                    )
                    .frame(
                        width: 22
                    )
                }

                Text(
                    title
                )
                .lineLimit(
                    2
                )
                .multilineTextAlignment(
                    .leading
                )

                Spacer(
                    minLength: 4
                )

                if let count {
                    Text(
                        "\(count)"
                    )
                    .font(
                        .system(
                            size: 13
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .font(
                .system(
                    size: 17,
                    weight: .medium
                )
            )
            .padding(
                .horizontal,
                14
            )
            .padding(
                .vertical,
                13
            )
            .frame(
                maxWidth: .infinity,
                minHeight: 50,
                alignment: .leading
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle(
                selected:
                    guide.selectedCategory
                    == key
            )
        )
    }

    // MARK: - Programme grid

    private func programmeGrid(
        now: Date
    ) -> some View {
        let rows =
            guide.visibleChannels

        return GeometryReader {
            geometry in

            let channelWidth:
                CGFloat = 250

            let timelineWidth =
                max(
                    240,
                    geometry.size.width
                    - channelWidth
                    - 12
                )

            VStack(
                spacing: 12
            ) {
                guideWindowControls

                HStack(
                    spacing: 12
                ) {
                    Text(
                        "ZENDER"
                    )
                    .font(
                        .system(
                            size: 15,
                            weight: .medium
                        )
                    )
                    .tracking(
                        2
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .frame(
                        width: channelWidth,
                        alignment: .leading
                    )

                    timeRuler(
                        width:
                            timelineWidth,
                        now:
                            now
                    )
                }
                .frame(
                    height: 35
                )

                if guide.loadingChannels {
                    ProgressView(
                        "Zenders laden..."
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )

                } else if rows.isEmpty {
                    emptyGuideView

                } else {
                    channelRows(
                        rows:
                            rows,
                        channelWidth:
                            channelWidth,
                        timelineWidth:
                            timelineWidth,
                        now:
                            now
                    )
                }
            }
        }
    }

    private var guideWindowControls: some View {
        HStack {
            Text(
                VeyraEPGFormat.day(
                    guide.windowStart
                )
            )
            .font(
                .system(
                    size: 18,
                    weight: .semibold
                )
            )

            Spacer()

            Button {
                guide.moveWindow(
                    -3
                )

            } label: {
                Label(
                    "3 uur",
                    systemImage:
                        "chevron.left"
                )
                .padding(
                    10
                )
            }
            .buttonStyle(
                VeyraEPGButtonStyle()
            )

            Button {
                guide.moveWindow(
                    3
                )

            } label: {
                HStack(
                    spacing: 8
                ) {
                    Text(
                        "3 uur"
                    )

                    Image(
                        systemName:
                            "chevron.right"
                    )
                }
                .padding(
                    10
                )
            }
            .buttonStyle(
                VeyraEPGButtonStyle()
            )
        }
        .font(
            .system(
                size: 16,
                weight: .semibold
            )
        )
    }

    private var emptyGuideView: some View {
        VStack(
            spacing: 14
        ) {
            if guide.selectedCategory
                == "favorites"
                && guide.searchText.isEmpty
            {
                Image(
                    systemName:
                        "star"
                )
                .font(
                    .system(
                        size: 36
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(
                        0.7
                    )
                )

                Text(
                    "Geen favorieten"
                )
                .font(
                    .system(
                        size: 22,
                        weight: .semibold
                    )
                )

                Text(
                    "Ga naar Alle zenders en houd een zender ingedrukt om hem aan Favorieten toe te voegen."
                )
                .foregroundStyle(
                    .secondary
                )

            } else {
                Text(
                    guide.searchText.isEmpty
                    ?
                    "Geen zichtbare zenders in deze selectie."
                    :
                    "Geen zoekresultaten in dit tijdvak."
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    private func channelRows(
        rows: [VeyraGuideChannel],
        channelWidth: CGFloat,
        timelineWidth: CGFloat,
        now: Date
    ) -> some View {
        ScrollViewReader {
            proxy in

            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                LazyVStack(
                    spacing: 8
                ) {
                    ForEach(
                        rows
                    ) { row in
                        HStack(
                            spacing: 12
                        ) {
                            channelButton(
                                row,
                                now: now
                            )
                            .frame(
                                width:
                                    channelWidth
                            )

                            programmeRow(
                                row,
                                width:
                                    timelineWidth,
                                now:
                                    now
                            )
                        }
                        .frame(
                            height: 108
                        )
                        .id(
                            row.id
                        )
                    }
                }
                .padding(
                    .vertical,
                    4
                )
            }
            .onChange(
                of: guide.selectedCategory
            ) { _ in
                if let id =
                    guide.visibleChannels
                        .first?
                        .id
                {
                    proxy.scrollTo(
                        id,
                        anchor: .top
                    )
                }
            }
        }
    }

    // MARK: - Time ruler

    private func timeRuler(
        width: CGFloat,
        now: Date
    ) -> some View {
        ZStack(
            alignment: .topLeading
        ) {
            ForEach(
                0..<6,
                id: \.self
            ) { index in
                Text(
                    VeyraEPGFormat.time(
                        guide.windowStart
                            .addingTimeInterval(
                                Double(index)
                                * 1_800
                            )
                    )
                )
                .font(
                    .system(
                        size: 17,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    .white.opacity(
                        0.6
                    )
                )
                .offset(
                    x:
                        width
                        * CGFloat(index)
                        / 6
                )
            }

            if now >= guide.windowStart
                && now < guide.windowEnd
            {
                Image(
                    systemName:
                        "arrowtriangle.down.fill"
                )
                .font(
                    .system(
                        size: 11
                    )
                )
                .foregroundStyle(
                    .cyan
                )
                .offset(
                    x:
                        width
                        * now.timeIntervalSince(
                            guide.windowStart
                        )
                        / guide.windowDuration
                        - 5,
                    y: 22
                )
            }
        }
        .frame(
            width: width,
            height: 35,
            alignment: .topLeading
        )
        .accessibilityHidden(
            true
        )
    }

    // MARK: - Channel

    private func channelButton(
        _ row: VeyraGuideChannel,
        now: Date
    ) -> some View {
        Button {
            selectChannel(
                row,
                now: now
            )

        } label: {
            HStack(
                spacing: 12
            ) {
                channelLogo(
                    row
                )

                VStack(
                    alignment: .leading,
                    spacing: 5
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
                        .system(
                            size: 19,
                            weight: .semibold
                        )
                    )
                    .lineLimit(
                        2
                    )

                    if guide.favorites
                        .contains(
                            row.id
                        )
                    {
                        Image(
                            systemName:
                                "star.fill"
                        )
                        .font(
                            .system(
                                size: 14
                            )
                        )
                        .foregroundStyle(
                            .cyan
                        )
                    }
                }

                Spacer(
                    minLength: 0
                )
            }
            .padding(
                12
            )
            .frame(
                maxWidth: .infinity,
                minHeight: 108,
                maxHeight: 108
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
        .accessibilityLabel(
            ChannelNameOverrideStore
                .effectiveName(
                    channelID:
                        row.channel.id,
                    defaultName:
                        row.channel.name
                )
        )
        .accessibilityHint(
            "Opent zenderinformatie en Kijk live"
        )
        .contextMenu {
            Button {
                editingLogoChannel =
                    row.channel

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
                    role: .destructive
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
    }

    private func selectChannel(
        _ row: VeyraGuideChannel,
        now: Date
    ) {
        selection =
            VeyraEPGSelection(
                row: row,
                programme:
                    guide.programmes(
                        for: row
                    )
                    .first {
                        $0.isOnAir(
                            at: now
                        )
                    }
            )
    }

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
                .font(
                    .system(
                        size: 32
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(
                        0.5
                    )
                )
            }
        }
        .id(
            logoOverrideVersion
        )
        .frame(
            width: 76,
            height: 68
        )
    }

    // MARK: - Programmes

    private func programmeRow(
        _ row: VeyraGuideChannel,
        width: CGFloat,
        now: Date
    ) -> some View {
        let slots =
            VeyraEPGSlot.make(
                guide.programmes(
                    for: row
                ),
                from:
                    guide.windowStart,
                to:
                    guide.windowEnd
            )

        return HStack(
            spacing: 0
        ) {
            ForEach(
                slots
            ) { slot in
                let span =
                    width
                    * slot.end
                        .timeIntervalSince(
                            slot.start
                        )
                    / guide.windowDuration

                Button {
                    selection =
                        VeyraEPGSelection(
                            row: row,
                            programme:
                                slot.programme
                        )

                } label: {
                    VStack(
                        alignment: .leading,
                        spacing: 5
                    ) {
                        if span > 60 {
                            Text(
                                slot.programme?
                                    .title
                                ??
                                (
                                    guide.loadingGuide
                                    ?
                                    "Gids laden..."
                                    :
                                    "Geen programma-informatie"
                                )
                            )
                            .font(
                                .system(
                                    size: 20,
                                    weight: .semibold
                                )
                            )
                            .lineLimit(
                                2
                            )

                            if let programme =
                                slot.programme,
                               span > 95
                            {
                                HStack(
                                    spacing: 7
                                ) {
                                    Text(
                                        VeyraEPGFormat.time(
                                            programme.start
                                        )
                                    )
                                    .foregroundStyle(
                                        .white.opacity(
                                            0.65
                                        )
                                    )

                                    if programme.isOnAir(
                                        at: now
                                    ) {
                                        Text(
                                            "NU"
                                        )
                                        .foregroundStyle(
                                            .cyan
                                        )
                                        .bold()
                                    }
                                }
                                .font(
                                    .system(
                                        size: 14
                                    )
                                )
                            }
                        }

                        Spacer(
                            minLength: 0
                        )
                    }
                    .padding(
                        .horizontal,
                        span > 60
                        ? 12
                        : 0
                    )
                    .padding(
                        .vertical,
                        12
                    )
                    .frame(
                        width:
                            max(
                                0,
                                span - 3
                            ),
                        height: 108,
                        alignment:
                            .topLeading
                    )
                    .clipped()
                }
                .buttonStyle(
                    VeyraEPGButtonStyle(
                        onAir:
                            slot.programme?
                                .isOnAir(
                                    at: now
                                )
                            == true
                    )
                )
                .frame(
                    width: span,
                    alignment: .leading
                )
                .accessibilityLabel(
                    (
                        slot.programme?
                            .title
                        ??
                        "Geen programma-informatie"
                    )
                    +
                    ", "
                    +
                    ChannelNameOverrideStore
                        .effectiveName(
                            channelID:
                                row.channel.id,
                            defaultName:
                                row.channel.name
                        )
                )
                .accessibilityHint(
                    "Toon programmadetails; begint niet automatisch met afspelen"
                )
            }
        }
        .frame(
            width: width,
            height: 88,
            alignment: .leading
        )
        .overlay(
            alignment: .leading
        ) {
            if now >= guide.windowStart
                && now < guide.windowEnd
            {
                Rectangle()
                    .fill(
                        Color.cyan.opacity(
                            0.7
                        )
                    )
                    .frame(
                        width: 2
                    )
                    .offset(
                        x:
                            width
                            * now.timeIntervalSince(
                                guide.windowStart
                            )
                            / guide.windowDuration
                    )
                    .allowsHitTesting(
                        false
                    )
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(
            spacing: 12
        ) {
            if guide.loadingGuide {
                ProgressView()
                    .scaleEffect(
                        0.65
                    )
            }

            Text(
                guide.loadingGuide
                ?
                "Programmagids laden; zenders zijn al beschikbaar."
                :
                (
                    guide.guideMessage
                    ??
                    "Selecteer een programma voor informatie of kies Kijk live."
                )
            )
            .font(
                .system(
                    size: 14
                )
            )
            .foregroundStyle(
                .white.opacity(
                    0.55
                )
            )
            .lineLimit(
                2
            )

            Spacer(
                minLength: 0
            )
        }
        .frame(
            minHeight: 24
        )
    }
}


// MARK: - Search

@MainActor
private struct LiveTVSearchView: View {
    @Binding
    var searchText: String

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        ZStack {
            VeyraEPGTheme.background
                .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 30
            ) {
                HStack {
                    Text(
                        "ZOEKEN"
                    )
                    .font(
                        .system(
                            size: 38,
                            weight: .light
                        )
                    )
                    .tracking(
                        4
                    )

                    Spacer()

                    Button {
                        dismiss()

                    } label: {
                        Image(
                            systemName:
                                "xmark"
                        )
                        .frame(
                            width: 60,
                            height: 60
                        )
                    }
                    .buttonStyle(
                        VeyraEPGButtonStyle()
                    )
                }

                TextField(
                    "Zoek zenders en programma's",
                    text:
                        $searchText
                )
                .font(
                    .system(
                        size: 28
                    )
                )
                .textInputAutocapitalization(
                    .never
                )
                .autocorrectionDisabled()
                .textFieldStyle(
                    .plain
                )
                .padding(
                    20
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                    .fill(
                        Color(
                            red: 0.035,
                            green: 0.10,
                            blue: 0.16
                        )
                    )
                )

                if !searchText.isEmpty {
                    Button {
                        searchText = ""

                    } label: {
                        Label(
                            "Zoekopdracht wissen",
                            systemImage:
                                "xmark.circle"
                        )
                        .padding(
                            16
                        )
                    }
                    .buttonStyle(
                        VeyraEPGButtonStyle()
                    )
                }

                Spacer()
            }
            .padding(
                60
            )
        }
        .foregroundStyle(
            .white
        )
    }
}


// MARK: - Selection

private struct VeyraEPGSelection:
    Identifiable
{
    let row:
        VeyraGuideChannel

    let programme:
        VeyraEPGProgramme?

    var id: String {
        "\(row.id):\(programme?.id ?? "channel")"
    }
}


// MARK: - Details

@MainActor
private struct VeyraEPGDetails: View {
    let selection:
        VeyraEPGSelection

    @ObservedObject
    var guide:
        VeyraEPGStore

    let onPlay:
        () -> Void

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        ZStack {
            VeyraEPGTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {
                    Text(
                        ChannelNameOverrideStore
                            .effectiveName(
                                channelID:
                                    selection.row
                                        .channel
                                        .id,
                                defaultName:
                                    selection.row
                                        .channel
                                        .name
                            )
                    )
                    .font(
                        .system(
                            size: 22,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        .cyan
                    )

                    Text(
                        selection.programme?
                            .title
                        ??
                        "Zenderinformatie"
                    )
                    .font(
                        .system(
                            size: 38,
                            weight: .semibold
                        )
                    )

                    if let programme =
                        selection.programme
                    {
                        Text(
                            VeyraEPGFormat.day(
                                programme.start
                            )
                            +
                            "  "
                            +
                            VeyraEPGFormat.time(
                                programme.start
                            )
                            +
                            " - "
                            +
                            VeyraEPGFormat.time(
                                programme.end
                            )
                        )
                        .foregroundStyle(
                            .cyan.opacity(
                                0.8
                            )
                        )

                        if !programme
                            .subtitle
                            .isEmpty
                        {
                            Text(
                                programme.subtitle
                            )
                            .font(
                                .title3
                            )
                        }

                        Text(
                            programme.summary
                                .isEmpty
                            ?
                            "Geen beschrijving beschikbaar."
                            :
                            programme.summary
                        )
                        .foregroundStyle(
                            .white.opacity(
                                0.75
                            )
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                        if programme.estimatedEnd {
                            Text(
                                "De eindtijd is afgeleid van het volgende programma."
                            )
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        if !programme.isOnAir(
                            at: Date()
                        ) {
                            Text(
                                "Kijk live opent de huidige uitzending van deze zender, niet dit geplande of afgelopen programma. Terugkijken is in deze gids nog niet ingebouwd."
                            )
                            .font(
                                .callout
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }

                    } else {
                        Text(
                            "Geen programma-informatie voor dit tijdvak. De livezender blijft beschikbaar."
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    HStack(
                        spacing: 20
                    ) {
                        Button(
                            action:
                                onPlay
                        ) {
                            Label(
                                "Kijk live",
                                systemImage:
                                    "play.fill"
                            )
                            .padding(
                                16
                            )
                        }
                        .buttonStyle(
                            VeyraEPGButtonStyle(
                                selected: true
                            )
                        )

                        Button {
                            guide.toggleFavorite(
                                selection.row
                            )

                        } label: {
                            Label(
                                guide.favorites
                                    .contains(
                                        selection.row.id
                                    )
                                ?
                                "Favoriet verwijderen"
                                :
                                "Favoriet maken",
                                systemImage:
                                    guide.favorites
                                        .contains(
                                            selection.row.id
                                        )
                                    ?
                                    "star.fill"
                                    :
                                    "star"
                            )
                            .padding(
                                16
                            )
                        }
                        .buttonStyle(
                            VeyraEPGButtonStyle()
                        )

                        Button(
                            "Sluiten"
                        ) {
                            dismiss()
                        }
                        .padding(
                            16
                        )
                        .buttonStyle(
                            VeyraEPGButtonStyle()
                        )
                    }
                }
                .frame(
                    maxWidth: 1200,
                    alignment: .leading
                )
                .padding(
                    60
                )
            }
        }
        .foregroundStyle(
            .white
        )
    }
}


// MARK: - Button style

private struct VeyraEPGButtonStyle:
    ButtonStyle
{
    var selected = false
    var onAir = false

    func makeBody(
        configuration:
            Configuration
    ) -> some View {
        VeyraEPGButtonSurface(
            label:
                configuration.label,
            pressed:
                configuration.isPressed,
            selected:
                selected,
            onAir:
                onAir
        )
    }
}


private struct VeyraEPGButtonSurface<
    Label: View
>:
    View
{
    let label: Label
    let pressed: Bool
    let selected: Bool
    let onAir: Bool

    @Environment(\.isFocused)
    private var isFocused

    @Environment(\.isEnabled)
    private var isEnabled

    var body: some View {
        label
            .foregroundStyle(
                .white
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .fill(
                    backgroundColor
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .strokeBorder(
                    isFocused
                    ?
                    Color.cyan
                    :
                    Color.cyan.opacity(
                        selected
                        ? 0.45
                        : 0.08
                    ),
                    lineWidth:
                        isFocused
                        ? 2
                        : 1
                )
            )
            .scaleEffect(
                isFocused
                ? 1.025
                : 1
            )
            .opacity(
                !isEnabled
                ? 0.4
                :
                pressed
                ? 0.8
                : 1
            )
            .animation(
                .easeOut(
                    duration: 0.12
                ),
                value:
                    isFocused
            )
    }

    private var backgroundColor:
        Color
    {
        if isFocused {
            return
                Color.cyan.opacity(
                    0.24
                )
        }

        if selected {
            return
                Color.cyan.opacity(
                    0.16
                )
        }

        if onAir {
            return
                Color(
                    red: 0.035,
                    green: 0.20,
                    blue: 0.25
                )
        }

        return Color(
            red: 0.035,
            green: 0.10,
            blue: 0.16
        )
    }
}


// MARK: - Theme

private enum VeyraEPGTheme {
    static var background:
        LinearGradient
    {
        LinearGradient(
            colors: [
                Color(
                    red: 0.01,
                    green: 0.04,
                    blue: 0.07
                ),
                Color(
                    red: 0.02,
                    green: 0.10,
                    blue: 0.16
                )
            ],
            startPoint:
                .topLeading,
            endPoint:
                .bottomTrailing
        )
    }
}


// MARK: - Formatting

@MainActor
private enum VeyraEPGFormat {
    private static let clock:
        DateFormatter =
    {
        let value =
            DateFormatter()

        value.locale =
            Locale(
                identifier:
                    "nl_BE"
            )

        value.timeZone =
            .autoupdatingCurrent

        value.dateFormat =
            "HH:mm"

        return value
    }()

    private static let calendar:
        DateFormatter =
    {
        let value =
            DateFormatter()

        value.locale =
            Locale(
                identifier:
                    "nl_BE"
            )

        value.timeZone =
            .autoupdatingCurrent

        value.dateFormat =
            "EEE d MMM"

        return value
    }()

    static func time(
        _ date: Date
    ) -> String {
        clock.string(
            from: date
        )
    }

    static func day(
        _ date: Date
    ) -> String {
        calendar.string(
            from: date
        )
    }
}


#Preview {
    NavigationStack {
        LiveTVView()
    }
}
