import SwiftUI
import Foundation

@MainActor
struct LiveTVView: View {
    @StateObject
    private var guide = VeyraEPGStore()

    @State
    private var showProviders = false

    @State
    private var selection: VeyraEPGSelection?

    @State
    private var selectedSource: PlayableSource?

    @State
    private var pendingSource: PlayableSource?

    // Logo aanpassen: lang drukken op een zenderlogo opent
    // `ChannelLogoPickerView`. `logoOverrideVersion` dwingt de betrokken
    // AsyncImage opnieuw te laden zodra een override is opgeslagen.
    @State
    private var editingLogoChannel: IPTVChannel?

    @State
    private var logoOverrideVersion = 0

    @Environment(\.scenePhase)
    private var scenePhase

    private let contentMargin: CGFloat =
        VeyraSpacing.page

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
            ) { _, newPhase in
                handleScenePhase(
                    newPhase
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
                spacing: 22
            ) {
                toolbar

                searchBar

                channelErrorView

                guideLayout

                footer
            }
            .padding(
                .horizontal,
                contentMargin
            )
            .padding(
                .top,
                36
            )
            .padding(
                .bottom,
                50
            )
        }
        .ignoresSafeArea(
            .container,
            edges: .horizontal
        )
    }

    @ViewBuilder
    private var channelErrorView: some View {
        if let error = guide.channelError {
            Text(error)
                .font(
                    .system(
                        size: 26,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    .orange
                )
        }
    }

    // MARK: - Guide layout

    private var guideLayout: some View {
        HStack(
            alignment: .top,
            spacing: 26
        ) {
            sidebar
                .frame(
                    width: 330
                )

            guideTimeline
        }
    }

    private var guideTimeline: some View {
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

    // MARK: - Root actions

    private func handleIPTVConfigurationChange() {
        selection = nil
        guide.reloadID = UUID()
    }

    private func handleScenePhase(
        _ phase: ScenePhase
    ) {
        guard phase == .active else {
            return
        }

        guide.reloadID = UUID()
    }

    private func handleSelectionDismiss() {
        guard let source = pendingSource else {
            return
        }

        pendingSource = nil
        selectedSource = source
    }

    private func startLivePlayback(
        _ selected: VeyraEPGSelection
    ) {
        pendingSource =
            guide.play(
                selected.row
            )

        selection = nil
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
        if provider.id == guide.activeProviderID {
            return
                provider.displayName
                + " (actief)"
        }

        return provider.displayName
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(
            spacing: 22
        ) {
            toolbarTitle

            Spacer(
                minLength: 10
            )

            providerButton

            nowButton

            refreshButton

            settingsButton
        }
        .font(
            .system(
                size: 24,
                weight: .semibold
            )
        )
        .focusSection()
    }

    private var toolbarTitle: some View {
        HStack(
            spacing: 18
        ) {
            RoundedRectangle(
                cornerRadius: 3
            )
            .fill(
                Color.cyan
            )
            .frame(
                width: 6,
                height: 56
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    "LIVE TV"
                )
                .font(
                    .system(
                        size: 46,
                        weight: .light
                    )
                )
                .tracking(
                    6.5
                )
                .foregroundStyle(
                    .white
                )

                Text(
                    "JOUW PROGRAMMAGIDS"
                )
                .font(
                    .system(
                        size: 17,
                        weight: .medium
                    )
                )
                .tracking(
                    2.6
                )
                .foregroundStyle(
                    .cyan.opacity(
                        0.78
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
                maxWidth: 370
            )
            .padding(
                .horizontal,
                24
            )
            .padding(
                .vertical,
                17
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
                24
            )
            .padding(
                .vertical,
                17
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
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
            .font(
                .system(
                    size: 27,
                    weight: .semibold
                )
            )
            .frame(
                width: 64,
                height: 64
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
        .disabled(
            guide.loadingChannels
                || guide.loadingGuide
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
            .font(
                .system(
                    size: 27,
                    weight: .semibold
                )
            )
            .frame(
                width: 64,
                height: 64
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
        .accessibilityLabel(
            "IPTV-providers beheren"
        )
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(
            spacing: 10
        ) {
            Spacer(
                minLength: 0
            )

            searchField

            if !guide.searchText.isEmpty {
                clearSearchButton
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .trailing
        )
    }

    private var searchField: some View {
        HStack(
            spacing: 12
        ) {
            Image(
                systemName:
                    "magnifyingglass"
            )
            .font(
                .system(
                    size: 22,
                    weight: .medium
                )
            )
            .foregroundStyle(
                .cyan.opacity(
                    0.78
                )
            )

            TextField(
                "Zoeken",
                text:
                    $guide.searchText
            )
            .font(
                .system(
                    size: 21
                )
            )
            .textInputAutocapitalization(
                .never
            )
            .autocorrectionDisabled()
            .textFieldStyle(
                .plain
            )
        }
        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            12
        )
        .frame(
            width: 340,
            height: 58
        )
        .background(
            RoundedRectangle(
                cornerRadius: 16,
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
        .overlay(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .strokeBorder(
                Color.cyan.opacity(
                    0.15
                ),
                lineWidth: 1
            )
        )
    }

    private var clearSearchButton: some View {
        Button {
            guide.searchText = ""

        } label: {
            Image(
                systemName:
                    "xmark"
            )
            .font(
                .system(
                    size: 19,
                    weight: .semibold
                )
            )
            .frame(
                width: 52,
                height: 52
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
        .accessibilityLabel(
            "Zoekopdracht wissen"
        )
    }

    // MARK: - Categories

    private var sidebar: some View {
        ScrollView(
            .vertical,
            showsIndicators: false
        ) {
            VStack(
                alignment: .leading,
                spacing: 11
            ) {
                allChannelsButton

                favoritesButton

                recentButton

                categoryHeader

                categoryButtons
            }
            .padding(
                4
            )
        }
        .focusSection()
    }

    private var allChannelsButton: some View {
        categoryButton(
            "Alle zenders",
            icon: "tv",
            key: "all",
            count:
                guide.channels.count
        )
    }

    private var favoritesButton: some View {
        categoryButton(
            "Favorieten",
            icon: "star",
            key: "favorites",
            count:
                favoriteCount
        )
    }

    private var recentButton: some View {
        categoryButton(
            "Recent geopend",
            icon:
                "clock.arrow.circlepath",
            key:
                "recent",
            count:
                recentCount
        )
    }

    private var favoriteCount: Int {
        guide.channels.reduce(
            into: 0
        ) { count, row in
            if guide.favorites.contains(
                row.id
            ) {
                count += 1
            }
        }
    }

    private var recentCount: Int {
        guide.channels.reduce(
            into: 0
        ) { count, row in
            if guide.recent.contains(
                row.id
            ) {
                count += 1
            }
        }
    }

    private var categoryHeader: some View {
        Text(
            "CATEGORIEËN"
        )
        .font(
            .system(
                size: 17,
                weight: .semibold
            )
        )
        .tracking(
            2.4
        )
        .foregroundStyle(
            .cyan.opacity(
                0.68
            )
        )
        .padding(
            .top,
            20
        )
        .padding(
            .bottom,
            7
        )
    }

    @ViewBuilder
    private var categoryButtons: some View {
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
            categoryButtonLabel(
                title: title,
                icon: icon,
                count: count
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

    private func categoryButtonLabel(
        title: String,
        icon: String?,
        count: Int?
    ) -> some View {
        HStack(
            spacing: 14
        ) {
            if let icon {
                Image(
                    systemName:
                        icon
                )
                .font(
                    .system(
                        size: 23
                    )
                )
                .frame(
                    width: 30
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
                minLength: 5
            )

            if let count {
                Text(
                    "\(count)"
                )
                .font(
                    .system(
                        size: 16
                    )
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .font(
            .system(
                size: 22,
                weight: .medium
            )
        )
        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            15
        )
        .frame(
            maxWidth: .infinity,
            minHeight: 64,
            alignment: .leading
        )
    }

    // MARK: - Programme guide

    private func programmeGrid(
        now: Date
    ) -> some View {
        GeometryReader { geometry in
            programmeGridContents(
                geometry:
                    geometry,
                now:
                    now
            )
        }
    }

    private func programmeGridContents(
        geometry: GeometryProxy,
        now: Date
    ) -> some View {
        let channelWidth:
            CGFloat = 250

        let timelineWidth =
            max(
                240,
                geometry.size.width
                    - channelWidth
                    - 16
            )

        return VStack(
            spacing: 16
        ) {
            guideWindowToolbar

            guideTimeHeader(
                channelWidth:
                    channelWidth,
                timelineWidth:
                    timelineWidth,
                now:
                    now
            )

            guideRows(
                channelWidth:
                    channelWidth,
                timelineWidth:
                    timelineWidth,
                now:
                    now
            )
        }
    }

    private var guideWindowToolbar: some View {
        HStack {
            Text(
                VeyraEPGFormat.day(
                    guide.windowStart
                )
            )
            .font(
                .system(
                    size: 27,
                    weight: .semibold
                )
            )

            Spacer()

            previousWindowButton

            nextWindowButton
        }
        .font(
            .system(
                size: 22,
                weight: .semibold
            )
        )
    }

    private var previousWindowButton: some View {
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
                16
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
    }

    private var nextWindowButton: some View {
        Button {
            guide.moveWindow(
                3
            )

        } label: {
            HStack(
                spacing: 10
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
                16
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
    }

    private func guideTimeHeader(
        channelWidth: CGFloat,
        timelineWidth: CGFloat,
        now: Date
    ) -> some View {
        HStack(
            spacing: 16
        ) {
            Text(
                "ZENDER"
            )
            .font(
                .system(
                    size: 18,
                    weight: .medium
                )
            )
            .tracking(
                2.6
            )
            .foregroundStyle(
                .secondary
            )
            .frame(
                width:
                    channelWidth,
                alignment:
                    .leading
            )

            timeRuler(
                width:
                    timelineWidth,
                now:
                    now
            )
        }
        .frame(
            height: 46
        )
    }

    @ViewBuilder
    private func guideRows(
        channelWidth: CGFloat,
        timelineWidth: CGFloat,
        now: Date
    ) -> some View {
        if guide.loadingChannels {
            ProgressView(
                "Zenders laden..."
            )
            .font(
                .system(
                    size: 22
                )
            )
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )

        } else if guide.visibleChannels.isEmpty {
            emptyGuideMessage

        } else {
            channelRows(
                channelWidth:
                    channelWidth,
                timelineWidth:
                    timelineWidth,
                now:
                    now
            )
        }
    }

    private var emptyGuideMessage: some View {
        Text(
            guide.searchText.isEmpty
                ? "Geen zichtbare zenders in deze selectie."
                : "Geen zoekresultaten in dit tijdvak."
        )
        .font(
            .system(
                size: 22
            )
        )
        .foregroundStyle(
            .secondary
        )
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }

    private func channelRows(
        channelWidth: CGFloat,
        timelineWidth: CGFloat,
        now: Date
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                LazyVStack(
                    spacing: 13
                ) {
                    ForEach(
                        guide.visibleChannels
                    ) { row in
                        guideChannelRow(
                            row:
                                row,
                            channelWidth:
                                channelWidth,
                            timelineWidth:
                                timelineWidth,
                            now:
                                now
                        )
                    }
                }
                .padding(
                    .vertical,
                    7
                )
            }
            .onChange(
                of:
                    guide.selectedCategory
            ) { _, _ in
                scrollToFirstChannel(
                    using:
                        proxy
                )
            }
        }
    }

    private func guideChannelRow(
        row: VeyraGuideChannel,
        channelWidth: CGFloat,
        timelineWidth: CGFloat,
        now: Date
    ) -> some View {
        HStack(
            spacing: 16
        ) {
            channelButton(
                row,
                now:
                    now
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
            height: 126
        )
        .id(
            row.id
        )
    }

    private func scrollToFirstChannel(
        using proxy:
            ScrollViewProxy
    ) {
        guard
            let id =
                guide.visibleChannels
                    .first?
                    .id
        else {
            return
        }

        proxy.scrollTo(
            id,
            anchor:
                .top
        )
    }

    // MARK: - Time ruler

    private func timeRuler(
        width: CGFloat,
        now: Date
    ) -> some View {
        ZStack(
            alignment:
                .topLeading
        ) {
            timeLabels(
                width:
                    width
            )

            if isNowInsideWindow(
                now
            ) {
                nowRulerMarker(
                    width:
                        width,
                    now:
                        now
                )
            }
        }
        .frame(
            width:
                width,
            height:
                42,
            alignment:
                .topLeading
        )
        .accessibilityHidden(
            true
        )
    }

    @ViewBuilder
    private func timeLabels(
        width: CGFloat
    ) -> some View {
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
                    size: 20,
                    weight: .medium
                )
            )
            .foregroundStyle(
                .white.opacity(
                    0.72
                )
            )
            .offset(
                x:
                    width
                    * CGFloat(index)
                    / 6
            )
        }
    }

    private func nowRulerMarker(
        width: CGFloat,
        now: Date
    ) -> some View {
        Image(
            systemName:
                "arrowtriangle.down.fill"
        )
        .font(
            .system(
                size: 14
            )
        )
        .foregroundStyle(
            .cyan
        )
        .offset(
            x:
                nowXPosition(
                    width:
                        width,
                    now:
                        now
                )
                - 7,
            y:
                26
        )
    }

    // MARK: - Channel button

    private func channelButton(
        _ row:
            VeyraGuideChannel,
        now: Date
    ) -> some View {
        Button {
            selectChannel(
                row,
                now:
                    now
            )

        } label: {
            channelButtonLabel(
                row
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
        .accessibilityLabel(
            ChannelNameOverrideStore.effectiveName(
                channelID: row.channel.id,
                defaultName: row.channel.name
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

            if ChannelLogoOverrideStore.logoURL(
                forChannelID:
                    row.channel.id
            ) != nil {
                Button(
                    role: .destructive
                ) {
                    ChannelLogoOverrideStore.removeOverride(
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
        _ row:
            VeyraGuideChannel,
        now: Date
    ) {
        let currentProgramme =
            guide.programmes(
                for: row
            )
            .first {
                $0.isOnAir(
                    at: now
                )
            }

        selection =
            VeyraEPGSelection(
                row:
                    row,
                programme:
                    currentProgramme
            )
    }

    private func channelButtonLabel(
        _ row:
            VeyraGuideChannel
    ) -> some View {
        HStack(
            spacing: 16
        ) {
            channelLogo(
                row
            )

            channelName(
                row
            )

            Spacer(
                minLength: 0
            )
        }
        .padding(
            16
        )
        .frame(
            maxWidth:
                .infinity,
            minHeight:
                116,
            maxHeight:
                116
        )
    }

    private func channelLogo(
        _ row:
            VeyraGuideChannel
    ) -> some View {
        AsyncImage(
            url:
                ChannelLogoOverrideStore.effectiveLogoURL(
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
                        size: 34
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

    private func channelName(
        _ row:
            VeyraGuideChannel
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            Text(
                ChannelNameOverrideStore.effectiveName(
                    channelID:
                        row.channel.id,
                    defaultName:
                        row.channel.name
                )
            )
            .font(
                .system(
                    size: 21,
                    weight: .semibold
                )
            )
            .lineLimit(
                2
            )

            if guide.favorites.contains(
                row.id
            ) {
                Image(
                    systemName:
                        "star.fill"
                )
                .font(
                    .system(
                        size: 16
                    )
                )
                .foregroundStyle(
                    .cyan
                )
            }
        }
    }

    // MARK: - Programme row

    private func programmeRow(
        _ row:
            VeyraGuideChannel,
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

        return ZStack(
            alignment:
                .leading
        ) {
            programmeSlots(
                slots:
                    slots,
                row:
                    row,
                width:
                    width,
                now:
                    now
            )

            if isNowInsideWindow(
                now
            ) {
                nowLine(
                    width:
                        width,
                    now:
                        now
                )
            }
        }
        .frame(
            width:
                width,
            height:
                116,
            alignment:
                .leading
        )
    }

    private func programmeSlots(
        slots: [VeyraEPGSlot],
        row: VeyraGuideChannel,
        width: CGFloat,
        now: Date
    ) -> some View {
        HStack(
            spacing: 0
        ) {
            ForEach(
                slots
            ) { slot in
                programmeSlot(
                    slot:
                        slot,
                    row:
                        row,
                    width:
                        width,
                    now:
                        now
                )
            }
        }
    }

    private func programmeSlot(
        slot: VeyraEPGSlot,
        row: VeyraGuideChannel,
        width: CGFloat,
        now: Date
    ) -> some View {
        let span =
            slotWidth(
                slot:
                    slot,
                totalWidth:
                    width
            )

        return Button {
            selection =
                VeyraEPGSelection(
                    row:
                        row,
                    programme:
                        slot.programme
                )

        } label: {
            programmeSlotLabel(
                slot:
                    slot,
                span:
                    span,
                now:
                    now
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle(
                onAir:
                    slot.programme?
                        .isOnAir(
                            at: now
                        )
                    == true,
                channelColor:
                    channelColor(
                        for: row
                    )
            )
        )
        .frame(
            width:
                span,
            alignment:
                .leading
        )
        .accessibilityLabel(
            programmeAccessibilityLabel(
                slot:
                    slot,
                row:
                    row
            )
        )
        .accessibilityHint(
            "Toon programmadetails; begint niet automatisch met afspelen"
        )
    }

    private func programmeSlotLabel(
        slot: VeyraEPGSlot,
        span: CGFloat,
        now: Date
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            if span > 60 {
                Text(
                    programmeTitle(
                        slot
                    )
                )
                .font(
                    .system(
                        size: 21,
                        weight: .semibold
                    )
                )
                .lineLimit(
                    2
                )

                if let programme =
                    slot.programme,
                   span > 105
                {
                    programmeTimeLabel(
                        programme,
                        now:
                            now
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
                ? 16
                : 0
        )
        .padding(
            .vertical,
            16
        )
        .frame(
            width:
                max(
                    0,
                    span - 3
                ),
            height:
                116,
            alignment:
                .topLeading
        )
        .clipped()
    }

    private func programmeTimeLabel(
        _ programme:
            VeyraEPGProgramme,
        now: Date
    ) -> some View {
        HStack(
            spacing: 9
        ) {
            Text(
                VeyraEPGFormat.time(
                    programme.start
                )
            )
            .foregroundStyle(
                .white.opacity(
                    0.72
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
                size: 16
            )
        )
    }

    private func programmeTitle(
        _ slot:
            VeyraEPGSlot
    ) -> String {
        if let title =
            slot.programme?.title
        {
            return title
        }

        if guide.loadingGuide {
            return
                "Gids laden..."
        }

        return
            "Geen programma-informatie"
    }

    private func programmeAccessibilityLabel(
        slot: VeyraEPGSlot,
        row: VeyraGuideChannel
    ) -> String {
        let title =
            slot.programme?.title
            ?? "Geen programma-informatie"

        return
            title
            + ", "
            + ChannelNameOverrideStore.effectiveName(
                channelID:
                    row.channel.id,
                defaultName:
                    row.channel.name
            )
    }

    private func slotWidth(
        slot: VeyraEPGSlot,
        totalWidth: CGFloat
    ) -> CGFloat {
        let duration =
            slot.end
                .timeIntervalSince(
                    slot.start
                )

        return
            totalWidth
            * duration
            / guide.windowDuration
    }

    // MARK: - Current time

    private func isNowInsideWindow(
        _ now: Date
    ) -> Bool {
        now >= guide.windowStart
            && now < guide.windowEnd
    }

    private func nowXPosition(
        width: CGFloat,
        now: Date
    ) -> CGFloat {
        let elapsed =
            now.timeIntervalSince(
                guide.windowStart
            )

        return
            width
            * elapsed
            / guide.windowDuration
    }

    private func nowLine(
        width: CGFloat,
        now: Date
    ) -> some View {
        Rectangle()
            .fill(
                Color.cyan.opacity(
                    0.82
                )
            )
            .frame(
                width: 3
            )
            .offset(
                x:
                    nowXPosition(
                        width:
                            width,
                        now:
                            now
                    )
            )
            .allowsHitTesting(
                false
            )
    }

    // MARK: - Channel color

    private func channelColor(
        for row:
            VeyraGuideChannel
    ) -> Color {
        let hash =
            abs(
                row.id.hashValue
            )

        let palette:
            [
                (
                    red: Double,
                    green: Double,
                    blue: Double
                )
            ] = [
                (0.3, 0.7, 0.9),
                (0.4, 0.8, 0.4),
                (0.9, 0.5, 0.3),
                (0.7, 0.4, 0.8),
                (0.9, 0.7, 0.3),
                (0.3, 0.8, 0.7),
                (0.9, 0.4, 0.5),
                (0.5, 0.7, 0.3),
                (0.8, 0.3, 0.6),
                (0.4, 0.6, 0.9),
                (0.9, 0.6, 0.2),
                (0.5, 0.8, 0.5)
            ]

        let index =
            hash
            % palette.count

        let color =
            palette[index]

        return Color(
            red:
                color.red,
            green:
                color.green,
            blue:
                color.blue
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(
            spacing: 14
        ) {
            if guide.loadingGuide {
                ProgressView()
                    .scaleEffect(
                        0.75
                    )
            }

            Text(
                footerMessage
            )
            .font(
                .system(
                    size: 17
                )
            )
            .foregroundStyle(
                .white.opacity(
                    0.62
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
            minHeight: 28
        )
    }

    private var footerMessage: String {
        if guide.loadingGuide {
            return
                "Programmagids laden; zenders zijn al beschikbaar."
        }

        return
            guide.guideMessage
            ?? "Selecteer een programma voor informatie of kies Kijk live."
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


// MARK: - Programme details

@MainActor
private struct VeyraEPGDetails:
    View
{
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
                    spacing: 30
                ) {
                    channelTitle

                    programmeTitle

                    programmeInformation

                    actionButtons
                }
                .frame(
                    maxWidth: 1360,
                    alignment: .leading
                )
                .padding(
                    52
                )
            }
        }
        .foregroundStyle(
            .white
        )
    }

    private var channelTitle:
        some View
    {
        Text(
            ChannelNameOverrideStore.effectiveName(
                channelID:
                    selection.row.channel.id,
                defaultName:
                    selection.row.channel.name
            )
        )
        .font(
            .system(
                size: 28,
                weight: .semibold
            )
        )
        .foregroundStyle(
            .cyan
        )
    }

    private var programmeTitle:
        some View
    {
        Text(
            selection.programme?.title
            ?? "Zenderinformatie"
        )
        .font(
            .system(
                size: 46,
                weight: .semibold
            )
        )
    }

    @ViewBuilder
    private var programmeInformation:
        some View
    {
        if let programme =
            selection.programme
        {
            Text(
                VeyraEPGFormat.day(
                    programme.start
                )
                + "  "
                + VeyraEPGFormat.time(
                    programme.start
                )
                + " - "
                + VeyraEPGFormat.time(
                    programme.end
                )
            )
            .font(
                .system(
                    size: 23,
                    weight: .medium
                )
            )
            .foregroundStyle(
                .cyan.opacity(
                    0.85
                )
            )

            if !programme.subtitle.isEmpty {
                Text(
                    programme.subtitle
                )
                .font(
                    .system(
                        size: 28,
                        weight: .medium
                    )
                )
            }

            Text(
                programme.summary.isEmpty
                    ? "Geen beschrijving beschikbaar."
                    : programme.summary
            )
            .font(
                .system(
                    size: 24
                )
            )
            .foregroundStyle(
                .white.opacity(
                    0.78
                )
            )
            .fixedSize(
                horizontal:
                    false,
                vertical:
                    true
            )

            if programme.estimatedEnd {
                Text(
                    "De eindtijd is afgeleid van het volgende programma."
                )
                .font(
                    .system(
                        size: 19
                    )
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
                    .system(
                        size: 21
                    )
                )
                .foregroundStyle(
                    .secondary
                )
            }

        } else {
            Text(
                "Geen programma-informatie voor dit tijdvak. De livezender blijft beschikbaar."
            )
            .font(
                .system(
                    size: 24
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    private var actionButtons:
        some View
    {
        HStack(
            spacing: 22
        ) {
            playButton

            favoriteButton

            closeButton
        }
    }

    private var playButton:
        some View
    {
        Button(
            action:
                onPlay
        ) {
            Label(
                "Kijk live",
                systemImage:
                    "play.fill"
            )
            .font(
                .system(
                    size: 23,
                    weight: .semibold
                )
            )
            .padding(
                20
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle(
                selected: true
            )
        )
    }

    private var favoriteButton:
        some View
    {
        Button {
            guide.toggleFavorite(
                selection.row
            )

        } label: {
            Label(
                favoriteTitle,
                systemImage:
                    favoriteIcon
            )
            .font(
                .system(
                    size: 23,
                    weight: .semibold
                )
            )
            .padding(
                20
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
    }

    private var favoriteTitle:
        String
    {
        guide.favorites.contains(
            selection.row.id
        )
        ? "Favoriet verwijderen"
        : "Favoriet maken"
    }

    private var favoriteIcon:
        String
    {
        guide.favorites.contains(
            selection.row.id
        )
        ? "star.fill"
        : "star"
    }

    private var closeButton:
        some View
    {
        Button(
            "Sluiten"
        ) {
            dismiss()
        }
        .font(
            .system(
                size: 23,
                weight: .semibold
            )
        )
        .padding(
            20
        )
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
    }
}


// MARK: - Veyra button style

private struct VeyraEPGButtonStyle:
    ButtonStyle
{
    var selected = false

    var onAir = false

    var channelColor:
        Color? = nil

    func makeBody(
        configuration: Configuration
    ) -> some View {
        VeyraEPGButtonSurface(
            label:
                configuration.label,
            pressed:
                configuration.isPressed,
            selected:
                selected,
            onAir:
                onAir,
            channelColor:
                channelColor
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

    let channelColor:
        Color?

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
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    backgroundColor
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .strokeBorder(
                    borderColor,
                    lineWidth:
                        isFocused
                        ? 2.5
                        : 1
                )
            )
            .opacity(
                opacity
            )
            .scaleEffect(
                isFocused
                    ? 1.025
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

    private var baseColor:
        Color
    {
        channelColor
        ?? Color.cyan
    }

    private var backgroundColor:
        Color
    {
        if isFocused {
            return
                baseColor.opacity(
                    0.32
                )
        }

        if selected {
            return
                baseColor.opacity(
                    0.22
                )
        }

        if onAir {
            return
                baseColor.opacity(
                    0.16
                )
        }

        return Color(
            red: 0.035,
            green: 0.10,
            blue: 0.16
        )
    }

    private var borderColor:
        Color
    {
        if isFocused {
            return
                baseColor
        }

        return
            baseColor.opacity(
                selected
                ? 0.50
                : 0.10
            )
    }

    private var opacity:
        Double
    {
        if !isEnabled {
            return 0.4
        }

        if pressed {
            return 0.8
        }

        return 1
    }
}


// MARK: - Theme

private enum VeyraEPGTheme {
    static var background:
        some View
    {
        VeyraBackground()
    }
}


// MARK: - Local time formatting

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
