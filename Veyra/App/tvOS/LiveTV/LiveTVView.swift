import SwiftUI
import Foundation

@MainActor
struct LiveTVView: View {
    @StateObject
    private var guide = VeyraEPGStore()

    // "Flow EPG": alternatieve gidsweergave, zie VeyraFlowEPGView.swift. Eén instelling, gedeeld
    // met een eventuele latere iOS-gids (zelfde sleutel = zelfde voorkeur op elk apparaat).
    @AppStorage("liveTV.epgViewMode") private var epgViewModeRaw = VeyraEPGViewMode.grid.rawValue
    private var epgViewMode: VeyraEPGViewMode { VeyraEPGViewMode(rawValue: epgViewModeRaw) ?? .grid }

    @StateObject private var flowPreview = VeyraFlowPreviewController()
    @State private var flowSelectedChannelID: String?

    private var flowSelectedRow: VeyraGuideChannel? {
        guide.visibleChannels.first { $0.id == flowSelectedChannelID }
            ?? guide.visibleChannels.first
    }

    @ObservedObject
    private var channelHealth = IPTVChannelHealthStore.shared

    @State
    private var showProviders = false

    @State
    private var showCategories = false

    @State
    private var showSearch = false

    @State
    private var showFavoriteOrder = false

    @State
    private var showFolders = false

    @State
    private var showMultiview = false

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

    private enum GuideFocus: Hashable {
        case channel(String)
        case programme(String, String)
    }

    @FocusState
    private var focusedGuideElement: GuideFocus?

    @Environment(\.scenePhase)
    private var scenePhase

    private let guideRowHeight: CGFloat = 120
    private let guideFocusInset: CGFloat = 12

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
            .sheet(
                isPresented: $showFolders
            ) {
                NavigationStack {
                    LiveTVFoldersListView()
                }
            }
            .sheet(
                isPresented: $showMultiview
            ) {
                MultiviewView(guide: guide)
            }
    }

    private var providerDialogLayer: some View {
        lifecycleLayer
            .veyraConfirmationDialog(
                "Kies je IPTV-provider",
                isPresented: $showProviders
            ) {
                providerDialogButtons
            }
            .veyraConfirmationDialog(
                "Kanalen",
                isPresented: $showCategories
            ) {
                categoryDialogButtons
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
            ) { _, phase in
                if phase != .active { flowPreview.stop() }
                handleScenePhase(
                    phase
                )
            }
            .onChange(of: guide.activeProviderID) { _, _ in
                flowPreview.stop()
                flowSelectedChannelID = nil
            }
            .onChange(of: showMultiview) { _, showing in
                if showing { flowPreview.stop() }
            }
            .onDisappear { flowPreview.stop() }
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
                24
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
        flowPreview.stop()
        // BELANGRIJK: geen `VeyraLocalLiveFallback` meer proactief vóór het
        // afspelen aanroepen. Die wisselde hier tot voor kort *altijd* stil
        // naar een andere geconfigureerde provider zodra er een kanaal met
        // dezelfde naam bestond — ook als de eigenlijk geselecteerde/actieve
        // provider prima werkte. Bij overlappende zenderlijsten (zeer
        // gebruikelijk bij IPTV-resellers) kon dat een werkend kanaal van de
        // actieve provider stilletjes vervangen door een kapotte/instabiele
        // kopie bij een andere provider — precies het willekeurige
        // afspeelgedrag dat hiermee werd waargenomen. Nu wordt gewoon de
        // bron van de daadwerkelijk geselecteerde/actieve provider gebruikt.
        let directSource = guide.play(selected.row)
        if selection != nil {
            // De rastersheet moet eerst sluiten voordat de speler opent.
            pendingSource = directSource
            selection = nil
        } else {
            // Flow heeft geen sheet: open de speler meteen.
            selectedSource = directSource
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
                showProviders = false
                guide.selectProvider(
                    provider
                )
            }
        }

        Button(
            "Annuleren",
            role: .cancel
        ) { showProviders = false }
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

    @ViewBuilder
    private var categoryDialogButtons: some View {
        Button("Alle zenders (\(guide.channels.count))") {
            showCategories = false
            guide.selectedCategory = "all"
        }

        Button("Favorieten (\(guide.favoriteRows.count))") {
            showCategories = false
            guide.selectedCategory = "favorites"
        }

        Button("Recent geopend (\(recentCount))") {
            showCategories = false
            guide.selectedCategory = "recent"
        }

        ForEach(guide.categories) { category in
            Button(category.name) {
                showCategories = false
                guide.selectedCategory = "group:" + category.id
            }
        }

        Button("Annuleren", role: .cancel) { showCategories = false }
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

            categoryButton

            flowToggleButton

            nowButton

            searchButton

            refreshButton

            foldersButton

            multiviewButton

            settingsButton
        }
        .font(
            .system(
                size: 20,
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

    /// Vervangt de vroegere vaste linkerbalk: uitklapbare knop die dezelfde
    /// keuzes toont (Alle zenders/Favorieten/Recent geopend/categorieën) via
    /// `categoryDialogButtons`, zodat de EPG-lijst zelf de volle breedte kan
    /// gebruiken.
    private var categoryButton: some View {
        Button {
            showCategories = true

        } label: {
            Label(
                currentCategoryTitle,
                systemImage: "line.3.horizontal"
            )
            .lineLimit(1)
            .frame(maxWidth: 260)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
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
            // Rechtstreeks force-reloaden i.p.v. alleen `reloadID` te
            // wijzigen -- anders deed deze knop niets zolang het in
            // Instellingen ingestelde verversinterval nog niet verstreken
            // was, want `reload()` las dan gewoon de schijfcache opnieuw in.
            Task { await guide.reload(force: true) }

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
            "Zenders en programmagids nu vernieuwen"
        )
    }

    /// Meerdere zenders tegelijk bekijken (2-4 vakken), vertrekkend van je favorieten --
    /// zie `MultiviewView`.
    private var multiviewButton: some View {
        Button {
            showMultiview = true

        } label: {
            Image(
                systemName:
                    "rectangle.split.2x2"
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
            "Multiview"
        )
        .disabled(
            guide.favoriteRows.isEmpty
        )
    }

    /// Eigen, over providers heen samengestelde kanalenmappen (bv. "Sport"
    /// met kanalen van meerdere providers) -- zie `LiveTVFoldersListView`.
    private var foldersButton: some View {
        Button {
            showFolders = true

        } label: {
            Image(
                systemName:
                    "folder"
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
            "Mijn mappen"
        )
    }

    /// "Flow EPG": wisselt tussen de klassieke grid en de nieuwe rij-per-zender-weergave
    /// (VeyraFlowEPGView), zonder de databron/logica te veranderen.
    private var flowToggleButton: some View {
        Button {
            flowPreview.stop()
            epgViewModeRaw = (epgViewMode == .grid ? VeyraEPGViewMode.flow : .grid).rawValue
        } label: {
            Image(systemName: epgViewMode == .grid ? "rectangle.grid.2x2" : "list.bullet.rectangle")
                .frame(width: 48, height: 48)
        }
        .buttonStyle(VeyraEPGButtonStyle())
        .accessibilityLabel(epgViewMode == .grid ? "Wissel naar Flow-weergave" : "Wissel naar rasterweergave")
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
        TimelineView(
            .periodic(
                from: .now,
                by: 60
            )
        ) { context in
            if epgViewMode == .flow {
                flowGuide(now: context.date)
            } else {
                programmeGrid(
                    now: context.date
                )
            }
        }
        .focusSection()
        .onChange(of: focusedGuideElement) { previous, current in
            handleGuideFocusChange(from: previous, to: current)
        }
        .padding(.horizontal, -40)
    }

    private func flowGuide(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VeyraFlowLivePreview(
                guide: guide,
                row: flowSelectedRow,
                now: now,
                logoOverrideVersion: logoOverrideVersion,
                controller: flowPreview,
                onPlay: { row in playFlowChannel(row, at: now) }
            )
            .frame(height: 360)

            VeyraFlowEPGView(
                guide: guide,
                channels: guide.visibleChannels,
                now: now,
                selectedChannelID: flowSelectedRow?.id,
                logoOverrideVersion: logoOverrideVersion,
                onPlay: { row in playFlowChannel(row, at: now) },
                onFocus: { row in
                    if flowSelectedChannelID != row.id {
                        flowSelectedChannelID = row.id
                    }
                    if flowPreview.channelID != row.id {
                        flowPreview.start(row)
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .onChange(of: flowSelectedRow?.id) { _, _ in
            // Filter- of providerwissels kunnen de selectie wijzigen zonder
            // focusgebeurtenis. Een focuswissel start zelf al direct af.
            if let row = flowSelectedRow {
                if flowPreview.channelID != row.id { flowPreview.start(row) }
            } else {
                flowPreview.stop()
            }
        }
        .onAppear {
            if let row = flowSelectedRow, flowPreview.channelID != row.id {
                flowPreview.start(row)
            }
        }
    }

    private func playFlowChannel(_ row: VeyraGuideChannel, at now: Date) {
        startLivePlayback(
            VeyraEPGSelection(
                row: row,
                programme: guide.programmes(for: row).first { $0.isOnAir(at: now) }
            )
        )
    }

    // MARK: - Categories
    //
    // Vroeger een vaste linkerbalk (`sidebar`) naast de gids; die nam blijvend
    // een kolom breedte in terwijl de EPG-lijst zelf smaller werd. Nu een
    // uitklapbare knop naast de providerknop ("TiviOne") in de werkbalk
    // (`categoryButton`/`categoryDialogButtons` hieronder), zodat de gids de
    // volle breedte krijgt en de zender-/categoriekeuze alsnog altijd
    // bereikbaar blijft.

    private var recentCount: Int {
        guide.channels.filter {
            guide.recent.contains(
                $0.id
            )
        }
        .count
    }

    /// Leesbare titel van de actieve categorie, getoond op de werkbalkknop
    /// die de categoriekeuze opent.
    private var currentCategoryTitle: String {
        switch guide.selectedCategory {
        case "all":
            return "Alle zenders"
        case "favorites":
            return "Favorieten"
        case "recent":
            return "Recent geopend"
        default:
            if guide.selectedCategory.hasPrefix("group:") {
                let id = String(guide.selectedCategory.dropFirst("group:".count))
                return guide.categories.first { $0.id == id }?.name ?? "Categorie"
            }
            return "Kanalen"
        }
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
                CGFloat = 265

            let timelineWidth =
                max(
                    240,
                    geometry.size.width
                    - channelWidth
                    - 12
                    - guideFocusInset * 2
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
                            size: 16,
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
                .padding(.horizontal, guideFocusInset)
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
        Text(
            VeyraEPGFormat.day(
                guide.windowStart
            )
        )
        .font(
            .system(
                size: 26,
                weight: .semibold
            )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
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
                            height: guideRowHeight
                        )
                        .id(
                            row.id
                        )
                    }
                }
                .padding(
                    .vertical,
                    6
                )
                .padding(.horizontal, guideFocusInset)
            }
            .onChange(
                of: guide.selectedCategory
            ) { _, _ in
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
                        size: 20,
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
                    alignment: .trailing,
                    spacing: 5
                ) {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        Text(
                            ChannelNameOverrideStore
                                .effectiveName(
                                    channelID: row.channel.id,
                                    defaultName: row.channel.name
                                )
                        )
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.trailing)

                        if guide.selectedCategory == "favorites" {
                            IPTVChannelHealthDot(
                                status: channelHealth.status(for: row.channel),
                                size: 12
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

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
                            VeyraColors.cyan
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(
                12
            )
            .frame(
                maxWidth: .infinity,
                minHeight: guideRowHeight,
                maxHeight: guideRowHeight
            )
        }
        .buttonStyle(
            VeyraEPGButtonStyle()
        )
        .focused($focusedGuideElement, equals: .channel(row.id))
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
        .task(id: guide.selectedCategory == "favorites" ? row.channel.streamURL.absoluteString : "") {
            if guide.selectedCategory == "favorites" {
                channelHealth.refreshIfNeeded(row.channel)
            }
        }
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

            // Rechtstreeks verbergen vanuit de zenderlijst zelf, zonder naar
            // "Live TV beheren" te moeten gaan -- zie VeyraEPGStore.setChannelVisible.
            Button(role: .destructive) {
                guide.setChannelVisible(
                    row.channel,
                    visible: false
                )
            } label: {
                Label(
                    "Zender verbergen",
                    systemImage:
                        "eye.slash"
                )
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
        VeyraAsyncImage(
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
            width: 84,
            height: 76
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
                let focusID = GuideFocus.programme(row.id, slot.id)
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
                                    size: 23,
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
                                            VeyraColors.cyan
                                        )
                                        .bold()
                                    }
                                }
                                .font(
                                    .system(
                                        size: 17
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
                        height: guideRowHeight,
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
                .focused($focusedGuideElement, equals: focusID)
                .onMoveCommand { direction in
                    moveGuideTimeline(direction, row: row, focusedSlot: slot)
                }
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
                    "Toon programmadetails; links en rechts verschuiven de tijdlijn"
                )
            }
        }
        .frame(
            width: width,
            height: guideRowHeight,
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
                        VeyraColors.cyan.opacity(
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

    private func moveGuideTimeline(
        _ direction: MoveCommandDirection,
        row: VeyraGuideChannel,
        focusedSlot: VeyraEPGSlot
    ) {
        guard direction == .left || direction == .right,
              focusedGuideElement == .programme(row.id, focusedSlot.id)
        else { return }

        shiftGuideWindow(direction == .left ? -1 : 1, row: row, focusedSlot: focusedSlot)
    }

    private func handleGuideFocusChange(
        from previous: GuideFocus?,
        to current: GuideFocus?
    ) {
        guard let previous, let current,
              case let .programme(rowID, slotID) = previous,
              case let .channel(channelID) = current,
              rowID == channelID,
              let row = guide.visibleChannels.first(where: { $0.id == rowID })
        else { return }

        let slots = VeyraEPGSlot.make(
            guide.programmes(for: row),
            from: guide.windowStart,
            to: guide.windowEnd
        )
        guard let focusedSlot = slots.first(where: { $0.id == slotID }) else { return }
        shiftGuideWindow(-1, row: row, focusedSlot: focusedSlot)
    }

    private func shiftGuideWindow(
        _ hours: Int,
        row: VeyraGuideChannel,
        focusedSlot: VeyraEPGSlot
    ) {
        let previousStart = guide.windowStart
        guide.moveWindow(hours)
        guard guide.windowStart != previousStart else { return }

        let nextRow = guide.visibleChannels.first(where: { $0.id == row.id })
            ?? guide.visibleChannels.first
        guard let nextRow else {
            focusedGuideElement = nil
            return
        }

        let nextSlots = VeyraEPGSlot.make(
            guide.programmes(for: nextRow),
            from: guide.windowStart,
            to: guide.windowEnd
        )
        let continuingProgramme = focusedSlot.programme.flatMap { programme in
            nextSlots.first(where: { $0.programme?.id == programme.id })
        }
        let nextSlot = continuingProgramme
            ?? (hours > 0 ? nextSlots.first : nextSlots.last)
        if let nextSlot {
            focusedGuideElement = .programme(nextRow.id, nextSlot.id)
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

    @State private var recorderMessage = ""
    @State private var showRecorderAlert = false
    @State private var schedulingRecording = false
    @State private var seriesRuleVersion = 0

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

                    if let programme = selection.programme,
                       programme.end > Date() {
                        Button {
                            Task { await scheduleRecording(programme) }
                        } label: {
                            Label("Neem deze aflevering op", systemImage: "record.circle")
                                .padding(16)
                        }
                        .buttonStyle(VeyraEPGButtonStyle())
                        .disabled(schedulingRecording)

                        let seriesActive = isRecordingWholeSeries(programme)
                        Button {
                            toggleSeriesRecording(programme)
                        } label: {
                            Label(
                                seriesActive ? "Stop met hele serie opnemen" : "Neem hele serie op",
                                systemImage: seriesActive ? "record.circle.fill" : "tv.badge.wifi"
                            )
                            .padding(16)
                        }
                        .buttonStyle(VeyraEPGButtonStyle(selected: seriesActive))
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
        .alert("VeyraHub Recorder", isPresented: $showRecorderAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(recorderMessage)
        }
    }

    private func scheduleRecording(_ programme: VeyraEPGProgramme) async {
        guard let hub = MediaServerStore().load().first(where: { $0.isVeyraHub }) else {
            recorderMessage = "Voeg VeyraHub eerst toe bij Mediaservers."
            showRecorderAlert = true
            return
        }

        schedulingRecording = true
        defer { schedulingRecording = false }
        do {
            try await VeyraHubRecorderClient(account: hub).schedule(
                title: programme.title,
                channel: ChannelNameOverrideStore.effectiveName(
                    channelID: selection.row.channel.id,
                    defaultName: selection.row.channel.name
                ),
                streamURL: selection.row.channel.streamURL,
                start: programme.start,
                end: programme.end
            )
            recorderMessage = "Opname gepland in VeyraHub."
        } catch {
            recorderMessage = error.localizedDescription
        }
        showRecorderAlert = true
    }

    private func isRecordingWholeSeries(_ programme: VeyraEPGProgramme) -> Bool {
        _ = seriesRuleVersion
        return SeriesRecordingDefaults.isRecordingWholeSeries(
            channelID: selection.row.id, title: programme.title
        )
    }

    private func toggleSeriesRecording(_ programme: VeyraEPGProgramme) {
        let enabling = !isRecordingWholeSeries(programme)
        let rule = SeriesRecordingDefaults.setRecordingWholeSeries(
            enabling, channelID: selection.row.id, title: programme.title
        )
        seriesRuleVersion += 1

        guard rule != nil else { return }
        recorderMessage = "Hele serie \"\(programme.title)\" wordt vanaf nu automatisch opgenomen."
        showRecorderAlert = true

        let row = selection.row
        Task {
            await VeyraHubRecorderScheduler.scheduleUpcomingEpisodes(
                programmeIndex: [row.channel.tvgID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "": guide.programmes(for: row)],
                channels: [row]
            )
        }
    }
}


// MARK: - Button style

struct VeyraEPGButtonStyle:
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
                    isFocused ? VeyraFrame.active
                        : (onAir || selected ? VeyraFrame.resting : VeyraEPGTheme.quietFrame),
                    lineWidth:
                        isFocused
                        ? 2.5
                        : (onAir || selected ? 1.5 : 1)
                )
            )
            .scaleEffect(
                isFocused
                ? 1.025
                : 1
            )
            .focusEffectDisabled()
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

    private var guideTheme: IPTVGuideTheme {
        IPTVGuideTheme(
            rawValue: UserDefaults.standard.string(forKey: IPTVPlaybackSettingsDefaults.guideThemeKey)
                ?? IPTVGuideTheme.colourful.rawValue
        ) ?? .colourful
    }

    private var backgroundColor:
        Color
    {
        // Focus blijft in elk gidsthema cyaan -- dat is het bedieningssignaal,
        // geen kleuraccent, en moet dus ook in Grijs/Zwart herkenbaar blijven.
        if isFocused {
            return
                VeyraColors.cyan.opacity(
                    0.24
                )
        }

        switch guideTheme {
        case .colourful:
            if selected { return VeyraColors.cyan.opacity(0.16) }
            if onAir { return Color(red: 0.035, green: 0.20, blue: 0.25) }
            return Color(red: 0.035, green: 0.10, blue: 0.16)

        case .grey:
            if selected { return Color(white: 0.30) }
            if onAir { return Color(white: 0.24) }
            return Color(white: 0.14)

        case .black:
            if selected { return Color(white: 0.20) }
            if onAir { return Color(white: 0.12) }
            return Color.black
        }
    }
}


// MARK: - Theme

private enum VeyraEPGTheme {
    private static var guideTheme: IPTVGuideTheme {
        IPTVGuideTheme(
            rawValue: UserDefaults.standard.string(forKey: IPTVPlaybackSettingsDefaults.guideThemeKey)
                ?? IPTVGuideTheme.colourful.rawValue
        ) ?? .colourful
    }

    static var quietFrame: LinearGradient {
        switch guideTheme {
        case .colourful:
            return LinearGradient(
                colors: [VeyraColors.cyan.opacity(0.10), VeyraColors.red.opacity(0.06)],
                startPoint: .leading, endPoint: .trailing
            )
        case .grey:
            return LinearGradient(
                colors: [Color.white.opacity(0.09), Color.white.opacity(0.09)],
                startPoint: .leading, endPoint: .trailing
            )
        case .black:
            return LinearGradient(
                colors: [Color.white.opacity(0.05), Color.white.opacity(0.05)],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }

    static var background:
        LinearGradient
    {
        switch guideTheme {
        case .colourful:
            return LinearGradient(
                colors: [
                    VeyraColors.background,
                    Color(red: 0.015, green: 0.09, blue: 0.13),
                    Color(red: 0.075, green: 0.015, blue: 0.045)
                ],
                startPoint: .bottomLeading, endPoint: .topTrailing
            )
        case .grey:
            return LinearGradient(
                colors: [Color(white: 0.07), Color(white: 0.12), Color(white: 0.07)],
                startPoint: .bottomLeading, endPoint: .topTrailing
            )
        case .black:
            return LinearGradient(
                colors: [Color.black, Color.black],
                startPoint: .bottomLeading, endPoint: .topTrailing
            )
        }
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
