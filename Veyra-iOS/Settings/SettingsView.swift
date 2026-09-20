import SwiftUI

enum SettingsDestination: String, Identifiable, CaseIterable, Hashable {
    case iptv
    case addons
    case mediaServers
    case general
    case subtitles
    case metadata
    case playback
    case shelves
    case account
    case cloudSync

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iptv: return "IPTV"
        case .addons: return "Addons"
        case .mediaServers: return "Mediaservers"
        case .general: return "Algemeen"
        case .subtitles: return "Ondertitels"
        case .metadata: return "Metadata"
        case .playback: return "Afspelen"
        case .shelves: return "Planken"
        case .account: return "Account"
        case .cloudSync: return "Gegevens en opslag"
        }
    }

    var subtitle: String {
        switch self {
        case .iptv: return "Live TV en VOD via Xtream of M3U"
        case .addons: return "Streams via gekoppelde addons"
        case .mediaServers: return "Jellyfin en andere eigen servers"
        case .general: return "Startscherm, sport en kaartweergave"
        case .subtitles: return "Taal, weergave en OpenSubtitles"
        case .metadata: return "Ratings op film- en seriepagina's"
        case .playback: return "Resolutie, taal en oversla-segmenten"
        case .shelves: return "Eigen rijen op het hoofdmenu"
        case .account: return "Trakt, TMDB en API-sleutels"
        case .cloudSync: return "iCloud-synchronisatie en opslaggebruik"
        }
    }

    var symbol: String {
        switch self {
        case .iptv: return "antenna.radiowaves.left.and.right"
        case .addons: return "puzzlepiece.extension.fill"
        case .mediaServers: return "server.rack"
        case .general: return "slider.horizontal.3"
        case .subtitles: return "captions.bubble"
        case .metadata: return "star.leadinghalf.filled"
        case .playback: return "play.circle"
        case .shelves: return "rectangle.grid.1x2"
        case .account: return "person.crop.circle"
        case .cloudSync: return "icloud"
        }
    }
}

struct SettingsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ObservedObject private var trakt = TraktStore.shared
    @ObservedObject private var cloudSync = CloudSettingsSync.shared

    @State private var iptvProviderCount = 0
    @State private var addonCount = 0
    @State private var mediaServerCount = 0
    @State private var iptvErrored = false
    @State private var selection: SettingsDestination?
    @State private var settingsPath = NavigationPath()
    @State private var categoryOrder: [SourceCategory] = SourceOrderDefaults.loadCategoryOrder()

    private let iptvStore = IPTVConfigurationStore()
    private let addonStore = AddonStore()
    private let mediaServerStore = MediaServerStore()

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: sidebar + detail, zodat instellingen en detail tegelijk zichtbaar zijn.
                NavigationSplitView {
                    sidebarList
                        .navigationSplitViewColumnWidth(min: 340, ideal: 400, max: 460)
                } detail: {
                    if let selection {
                        destinationView(selection)
                    } else {
                        ZStack {
                            VeyraColors.background.ignoresSafeArea()
                            ContentUnavailableView(
                                "Kies een instelling",
                                systemImage: "gearshape",
                                description: Text("Selecteer een onderdeel in de zijbalk.")
                            )
                        }
                    }
                }
            } else {
                // iPhone: klassieke gestapelde navigatie.
                //
                // Instellingen zit op iPhone altijd achter het automatische "More"-tabblad
                // (er zijn meer dan 4 tabs), en dat "More"-scherm heeft zelf al een eigen
                // navigatiebalk met terugknop. Onze eigen NavigationStack hieronder krijgt
                // dus een TWEEDE navigatiebalk zodra we iets pushen, wat een dubbele
                // terugpijl gaf. Daarom verbergen we de buitenste (More-)balk zodra we
                // dieper dan het hoofdmenu zitten, en laten we alleen de eigen balk van het
                // gepushte scherm (met zijn eigen terugknop naar het hoofdmenu) zichtbaar.
                NavigationStack(path: $settingsPath) {
                    sidebarList
                        .navigationDestination(for: SettingsDestination.self) { destination in
                            destinationView(destination)
                        }
                }
                .toolbar(settingsPath.isEmpty ? .visible : .hidden, for: .navigationBar)
            }
        }
        .onAppear { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .iptvConfigurationDidChange)) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: .veyraAddonConfigurationDidChange)) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: .veyraMediaServerConfigurationDidChange)) { _ in reload() }
        .task { await trakt.refreshIfNeeded() }
    }

    // MARK: - Sidebar / main list

    private var sidebarList: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    header

                    VStack(alignment: .leading, spacing: 14) {
                        Text("BRONNEN")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(VeyraColors.secondary)

                        ForEach(categoryOrder) { category in
                            bronnenRow(for: category)
                        }

                        Text("Schik de kaarten met de pijltjes; de volgorde hier bepaalt de volgorde bij het zoeken naar afspeelbronnen.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("WEERGAVE")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(VeyraColors.secondary)

                        settingsCard(.general, status: "", statusColor: VeyraColors.cyan)
                        settingsCard(.subtitles, status: "", statusColor: VeyraColors.cyan)
                        settingsCard(.metadata, status: "", statusColor: VeyraColors.cyan)
                        settingsCard(.playback, status: "", statusColor: VeyraColors.cyan)
                        settingsCard(.shelves, status: "", statusColor: VeyraColors.cyan)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("ACCOUNT")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(VeyraColors.secondary)

                        // Trakt (koppelen, synchroniseren, ontkoppelen) zit
                        // hier onder Account, samen met de TMDB/Trakt
                        // API-sleutels — niet meer als los item op het
                        // hoofdmenu.
                        settingsCard(
                            .account,
                            status: trakt.isConnected ? "Trakt verbonden" : "Trakt niet gekoppeld",
                            statusColor: trakt.isConnected ? VeyraColors.cyan : VeyraColors.secondary
                        )
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("GEGEVENS EN OPSLAG")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(VeyraColors.secondary)

                        settingsCard(
                            .cloudSync,
                            status: cloudSync.isEnabled ? "iCloud-sync aan" : "iCloud-sync uit",
                            statusColor: cloudSync.isEnabled ? VeyraColors.cyan : VeyraColors.secondary
                        )
                    }

                    versionInformation
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [VeyraColors.cyan, VeyraColors.red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("Instellingen")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Beheer je bronnen, kijkprofiel en appgegevens.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()
        }
    }

    // MARK: - Settings card

    private func settingsCard(
        _ destination: SettingsDestination,
        status: String,
        statusColor: Color
    ) -> some View {
        let card = HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VeyraColors.cyan.opacity(0.14))

                Image(systemName: destination.symbol)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(VeyraColors.cyan)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Text(destination.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.60))

                if !status.isEmpty {
                    Text(status)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(statusColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VeyraColors.cyan.opacity(0.55))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .veyraGlass(radius: VeyraRadius.card)

        return Group {
            if horizontalSizeClass == .regular {
                Button {
                    selection = destination
                } label: {
                    card
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: destination) {
                    card
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Bronnen (categorievolgorde)

    /// Eén categorie in BRONNEN, met omhoog/omlaag-knoppen om de
    /// categorievolgorde te herschikken — dit hoort thuis in dezelfde
    /// BRONNEN-groep, geen eigen tweede "Bronnen"-instelling.
    @ViewBuilder
    private func bronnenRow(for category: SourceCategory) -> some View {
        switch category {
        case .mediaServers:
            reorderableRow(category) {
                settingsCard(
                    .mediaServers,
                    status: mediaServerCount == 0 ? "Niet gekoppeld" : "\(mediaServerCount) gekoppeld",
                    statusColor: VeyraColors.cyan
                )
            }
        case .iptv:
            reorderableRow(category) {
                settingsCard(.iptv, status: iptvStatus, statusColor: iptvStatusColor)
            }
        case .addons:
            reorderableRow(category) {
                settingsCard(
                    .addons,
                    status: addonCount == 0 ? "Niet ingesteld" : "\(addonCount) actief",
                    statusColor: VeyraColors.cyan
                )
            }
        }
    }

    private func reorderableRow(
        _ category: SourceCategory,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack(spacing: 10) {
            content()

            VStack(spacing: 2) {
                Button {
                    moveCategory(category, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .disabled(categoryOrder.first == category)

                Divider().frame(width: 18).overlay(VeyraColors.ice.opacity(0.2))

                Button {
                    moveCategory(category, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .disabled(categoryOrder.last == category)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(VeyraColors.ice)
            .frame(width: 30)
            .background(
                Capsule().fill(VeyraColors.ice.opacity(0.12))
            )
        }
    }

    private func moveCategory(_ category: SourceCategory, by offset: Int) {
        guard let index = categoryOrder.firstIndex(of: category) else { return }
        let destination = index + offset
        guard categoryOrder.indices.contains(destination) else { return }
        categoryOrder.swapAt(index, destination)
        SourceOrderDefaults.saveCategoryOrder(categoryOrder)
    }

    // MARK: - Destination

    @ViewBuilder
    private func destinationView(_ destination: SettingsDestination) -> some View {
        switch destination {
        case .iptv: IPTVAccountsView()
        case .addons: AddonsSettingsView()
        case .mediaServers: MediaServersSettingsView()
        case .general: GeneralSettingsView()
        case .subtitles: SubtitlePreferencesView()
        case .metadata: MetadataSettingsView()
        case .playback: PlaybackSettingsView()
        case .shelves: ShelvesSettingsView()
        case .account: AccountView()
        case .cloudSync: CloudSyncSettingsView()
        }
    }

    // MARK: - Status

    private var iptvStatus: String {
        if iptvErrored { return "Controle mislukt" }
        return iptvProviderCount == 0 ? "Niet ingesteld" : "\(iptvProviderCount) provider(s)"
    }

    private var iptvStatusColor: Color {
        if iptvErrored { return .orange }
        return iptvProviderCount == 0 ? VeyraColors.secondary : VeyraColors.cyan
    }

    // MARK: - Version

    private var versionInformation: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(VeyraColors.cyan.opacity(0.65))

            Text("Veyra \(appVersionString) · voor iPhone en iPad")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.50))

            Spacer()
        }
        .padding(.top, 8)
    }

    private func reload() {
        do {
            iptvProviderCount = try iptvStore.loadProviders().count
            iptvErrored = false
        } catch {
            iptvProviderCount = 0
            iptvErrored = true
        }
        addonCount = addonStore.load().count
        mediaServerCount = mediaServerStore.load().count
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
