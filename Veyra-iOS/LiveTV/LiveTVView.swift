import SwiftUI
#if os(iOS)
import UIKit
#endif

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

    @State
    private var showRecordings = false

    @State
    private var showFolders = false

    @State
    private var showProviders = false

    @State
    private var showCategories = false

    @State
    private var displayMode: LiveTVDisplayMode = .channels

    @AppStorage("liveTV.epgViewMode") private var epgViewModeRaw = VeyraEPGViewMode.grid.rawValue
    private var epgViewMode: VeyraEPGViewMode { VeyraEPGViewMode(rawValue: epgViewModeRaw) ?? .grid }

    @StateObject private var flowPreview = VeyraFlowPreviewController()
    @State private var flowSelectedChannelID: String?
    @State private var showFlowPreview = false
    @State private var pendingFlowSource: PlayableSource?

    private var flowSelectedRow: VeyraGuideChannel? {
        guide.visibleChannels.first { $0.id == flowSelectedChannelID }
            ?? guide.visibleChannels.first
    }

    @Environment(\.scenePhase) private var scenePhase

    @Environment(\.horizontalSizeClass)
    private var sizeClass

    // Opnames is op iPad/Mac een eigen tab/zijbalk-item (past daar naast de
    // rest); op iPhone past dat niet meer zonder dat de tabbalk onder "Meer"
    // wegvalt, dus daar blijft deze knop de enige weg naar het opname-
    // overzicht. Dit bestand compileert ook mee in het macOS-target (geen
    // UIDevice daar), vandaar de platformcheck.
    private var isPad: Bool {
        #if os(macOS)
        true
        #else
        UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }

    var body: some View {
        VeyraDynamicBackgroundScope {
            NavigationStack {
                ZStack {
                    VeyraBackground()
                        .ignoresSafeArea()

                    VStack(
                        spacing: 0
                    ) {
                        // Zelfde opbouw als tvOS (`LiveTVView.swift` daar): titel + één rij
                        // knoppen i.p.v. gestapelde segmented pickers, zodat beide platformen
                        // hetzelfde scherm laten zien.
                        toolbarHeader

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
                    Timer.publish(every: 1_800, on: .main, in: .common).autoconnect()
                ) { _ in
                    guide.reloadID = UUID()
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
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { flowPreview.stop() }
                }
                .onChange(of: displayMode) { _, _ in flowPreview.stop() }
                .onChange(of: epgViewModeRaw) { _, _ in flowPreview.stop() }
                .onChange(of: guide.activeProviderID) { _, _ in
                    flowPreview.stop()
                    flowSelectedChannelID = nil
                }
                .onChange(of: showFolders) { _, showing in
                    if showing { flowPreview.stop() }
                }
                .onChange(of: showRecordings) { _, showing in
                    if showing { flowPreview.stop() }
                }
                .onDisappear { flowPreview.stop() }
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
                // Opnames/Mijn mappen/Vernieuwen/Ordenen zitten nu in `toolbarHeader`
                // hierboven (zelfde opbouw als tvOS) i.p.v. in de systeem-navigatiebalk.
                .veyraConfirmationDialog("Kies je IPTV-provider", isPresented: $showProviders) {
                    providerDialogButtons
                }
                .veyraConfirmationDialog("Kanalen", isPresented: $showCategories) {
                    categoryDialogButtons
                }
                .sheet(isPresented: $showRecordings) {
                    VeyraRecordingsView()
                }
                .sheet(isPresented: $showFolders) {
                    NavigationStack {
                        LiveTVFoldersListView()
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
                .sheet(isPresented: $showFlowPreview, onDismiss: {
                    if let source = pendingFlowSource {
                        pendingFlowSource = nil
                        selectedSource = source
                    }
                }) {
                    NavigationStack {
                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            VeyraPortableFlowPreview(
                                guide: guide,
                                row: flowSelectedRow,
                                now: context.date,
                                controller: flowPreview,
                                onPlay: playFlowChannel
                            )
                        }
                        .navigationTitle("Live voorbeeld")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Sluiten") { showFlowPreview = false }
                            }
                        }
                    }
                }
            }

        }
    }

    // MARK: - Toolbar (zelfde opbouw als tvOS)

    private var toolbarHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(VeyraColors.cyan)
                    .frame(width: 3, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text("LIVE TV")
                        .font(.system(size: 20, weight: .light))
                        .tracking(3)
                    Text("JOUW PROGRAMMAGIDS")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(VeyraColors.cyan.opacity(0.75))
                }

                Spacer(minLength: 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    providerButton
                    categoryButton
                    modeToggleButton
                    if displayMode == .guide {
                        flowToggleButton
                    }
                    nowButton
                    refreshButton
                    foldersButton
                    if guide.selectedCategory == "favorites", !guide.favoriteRows.isEmpty {
                        favoriteOrderButton
                    }
                    if !isPad {
                        recordingsButton
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var toolbarLabelFont: Font { .system(size: 14, weight: .semibold) }

    private var providerButton: some View {
        Button {
            showProviders = true
        } label: {
            Label(guide.providerName, systemImage: "antenna.radiowaves.left.and.right")
                .lineLimit(1)
                .font(toolbarLabelFont)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(VeyraEPGPillButtonStyle())
        .disabled(guide.providers.isEmpty)
    }

    private var categoryButton: some View {
        Button {
            showCategories = true
        } label: {
            Label(currentCategoryTitle, systemImage: "line.3.horizontal")
                .lineLimit(1)
                .font(toolbarLabelFont)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(VeyraEPGPillButtonStyle())
    }

    /// "Kanalen" (platte lijst) versus "Gids" (programmaraster/Flow) -- op tvOS bestaat enkel de
    /// gids, maar de eenvoudige kanalenlijst blijft hier beschikbaar als compacte knop i.p.v. een
    /// grote segmented control.
    private var modeToggleButton: some View {
        Button {
            displayMode = displayMode == .channels ? .guide : .channels
        } label: {
            Image(systemName: displayMode == .channels ? "list.bullet" : "rectangle.grid.2x2")
                .frame(width: 44, height: 44)
        }
        .buttonStyle(VeyraEPGIconButtonStyle())
        .accessibilityLabel(displayMode == .channels ? "Wissel naar programmagids" : "Wissel naar kanalenlijst")
    }

    private var flowToggleButton: some View {
        Button {
            flowPreview.stop()
            epgViewModeRaw = (epgViewMode == .grid ? VeyraEPGViewMode.flow : .grid).rawValue
        } label: {
            Image(systemName: epgViewMode == .grid ? "rectangle.grid.2x2" : "list.bullet.rectangle")
                .frame(width: 44, height: 44)
        }
        .buttonStyle(VeyraEPGIconButtonStyle())
        .accessibilityLabel(epgViewMode == .grid ? "Wissel naar Flow-weergave" : "Wissel naar rasterweergave")
    }

    private var nowButton: some View {
        Button {
            guide.showNow()
        } label: {
            Label("Nu", systemImage: "clock")
                .font(toolbarLabelFont)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(VeyraEPGPillButtonStyle())
    }

    private var refreshButton: some View {
        Button {
            Task { await guide.reload(force: true) }
        } label: {
            Image(systemName: "arrow.clockwise")
                .frame(width: 44, height: 44)
        }
        .buttonStyle(VeyraEPGIconButtonStyle())
        .accessibilityLabel("Zenders en programmagids nu vernieuwen")
    }

    private var foldersButton: some View {
        Button {
            showFolders = true
        } label: {
            Image(systemName: "folder")
                .frame(width: 44, height: 44)
        }
        .buttonStyle(VeyraEPGIconButtonStyle())
        .accessibilityLabel("Mijn mappen")
    }

    private var favoriteOrderButton: some View {
        Button {
            showFavoriteOrder = true
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .frame(width: 44, height: 44)
        }
        .buttonStyle(VeyraEPGIconButtonStyle())
        .accessibilityLabel("Volgorde favorieten aanpassen")
    }

    private var recordingsButton: some View {
        Button {
            showRecordings = true
        } label: {
            Image(systemName: "record.circle")
                .frame(width: 44, height: 44)
        }
        .buttonStyle(VeyraEPGIconButtonStyle())
        .accessibilityLabel("Opnames")
    }

    private var recentCount: Int {
        guide.channels.filter { guide.recent.contains($0.id) }.count
    }

    /// Leesbare titel van de actieve categorie, getoond op de werkbalkknop die de categoriekeuze
    /// opent -- zelfde logica als tvOS.
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

    @ViewBuilder
    private var providerDialogButtons: some View {
        ForEach(guide.providers) { provider in
            Button(providerTitle(provider)) {
                showProviders = false
                guide.selectProvider(provider)
            }
        }
        Button("Annuleren", role: .cancel) { showProviders = false }
    }

    private func providerTitle(_ provider: IPTVStoredProvider) -> String {
        if provider.id == guide.activeProviderID {
            return provider.displayName + " (actief)"
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
            if displayMode == .guide {
                if epgViewMode == .flow {
                    flowGuide
                } else {
                    LiveTVGuideView(guide: guide, logoOverrideVersion: logoOverrideVersion) { row in
                        selectedSource = guide.play(row)
                    }
                }
            } else {
                channelList
            }
        }
    }

    private var flowGuide: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(alignment: .top, spacing: 12) {
                EmptyView()
                    .onAppear {
                        guard isPad, flowPreview.engine == nil, let row = flowSelectedRow else { return }
                        selectFlowChannel(row)
                    }
                VeyraFlowEPGView(
                    guide: guide,
                    channels: guide.visibleChannels,
                    now: context.date,
                    selectedChannelID: flowSelectedRow?.id,
                    logoOverrideVersion: logoOverrideVersion,
                    onPlay: playFlowChannel,
                    onFocus: selectFlowChannel
                )

                if isPad {
                    VeyraPortableFlowPreview(
                        guide: guide,
                        row: flowSelectedRow,
                        now: context.date,
                        controller: flowPreview,
                        onPlay: playFlowChannel
                    )
                    .frame(width: 340)
                }
            }
            // GEEN `.onChange(of: flowSelectedRow?.id) { flowPreview.stop() }` meer hier: dat
            // stopte de voorvertoning meteen weer nadat `selectFlowChannel` hieronder hem net
            // had gestart (de state-wijziging die de selectie zet, triggert deze onChange op de
            // volgende render-cyclus, ná de `flowPreview.start(row)`-aanroep eronder) -- daardoor
            // startte "Voorvertoning meteen tonen" in de praktijk nooit zichtbaar op.
        }
    }

    private func selectFlowChannel(_ row: VeyraGuideChannel) {
        if flowSelectedChannelID != row.id {
            flowPreview.stop()
            flowSelectedChannelID = row.id
        }
        // Voorvertoning meteen tonen i.p.v. een aparte "Voorvertoning"-druk te vereisen.
        flowPreview.start(row)
        if !isPad { showFlowPreview = true }
    }

    private func playFlowChannel(_ row: VeyraGuideChannel) {
        flowPreview.stop()
        let source = guide.play(row)
        if showFlowPreview {
            pendingFlowSource = source
            showFlowPreview = false
        } else {
            selectedSource = source
        }
    }

    // MARK: - Channel list

    @ViewBuilder
    private var channelList: some View {
        if sizeClass == .regular {
            channelGrid
        } else {
            channelPlainList
        }
    }

    /// iPad: kanalen als kaarten in meerdere kolommen in plaats van één lange lijst.
    private var channelGrid: some View {
        VeyraScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 320), spacing: 14)],
                spacing: 14
            ) {
                ForEach(guide.visibleChannels) { row in
                    Button {
                        selectedSource = guide.play(row)
                    } label: {
                        HStack(spacing: 14) {
                            channelLogo(row)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    ChannelNameOverrideStore.effectiveName(
                                        channelID: row.channel.id,
                                        defaultName: row.channel.name
                                    )
                                )
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                                if guide.favorites.contains(row.id) {
                                    Label("Favoriet", systemImage: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(VeyraColors.cyan)
                                }
                            }

                            Spacer()

                            Image(systemName: "play.fill")
                                .foregroundStyle(VeyraColors.cyan)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(VeyraColors.surface)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var channelPlainList: some View {
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
        .scrollContentBackground(.hidden)
        .veyraScrollingBackground(legacyList: true)
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

private enum LiveTVDisplayMode: Hashable {
    case channels
    case guide
}

// MARK: - Werkbalkstijlen (zelfde opbouw als tvOS' `VeyraEPGButtonStyle`, maar met
// aanraakgrootte/glasmateriaal i.p.v. de focus-gedreven stijl van Apple TV)

private struct VeyraEPGPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(VeyraColors.cyan.opacity(0.35), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct VeyraEPGIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(
                Circle().strokeBorder(VeyraColors.cyan.opacity(0.35), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
