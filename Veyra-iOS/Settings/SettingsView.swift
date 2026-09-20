import SwiftUI

enum SettingsDestination: String, Identifiable, CaseIterable, Hashable {
    case iptv
    case addons
    case mediaServers
    case trakt
    case subtitles
    case metadata
    case shelves
    case account
    case cloudSync

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iptv: return "IPTV"
        case .addons: return "Addons"
        case .mediaServers: return "Mediaservers"
        case .trakt: return "Trakt"
        case .subtitles: return "Ondertitels"
        case .metadata: return "Metadata"
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
        case .trakt: return "Kijkgeschiedenis, voortgang en lijsten"
        case .subtitles: return "Standaardtaal en OpenSubtitles"
        case .metadata: return "Ratings op film- en seriepagina's"
        case .shelves: return "Eigen rijen op het hoofdmenu"
        case .account: return "API-sleutels en profiel"
        case .cloudSync: return "iCloud-synchronisatie en opslaggebruik"
        }
    }

    var symbol: String {
        switch self {
        case .iptv: return "antenna.radiowaves.left.and.right"
        case .addons: return "puzzlepiece.extension.fill"
        case .mediaServers: return "server.rack"
        case .trakt: return "checkmark.circle"
        case .subtitles: return "captions.bubble"
        case .metadata: return "star.leadinghalf.filled"
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
                NavigationStack {
                    sidebarList
                        .navigationDestination(for: SettingsDestination.self) { destination in
                            destinationView(destination)
                        }
                }
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

                        settingsCard(
                            .iptv,
                            status: iptvStatus,
                            statusColor: iptvStatusColor
                        )
                        settingsCard(
                            .addons,
                            status: addonCount == 0 ? "Niet ingesteld" : "\(addonCount) actief",
                            statusColor: VeyraColors.cyan
                        )
                        settingsCard(
                            .mediaServers,
                            status: mediaServerCount == 0 ? "Niet gekoppeld" : "\(mediaServerCount) gekoppeld",
                            statusColor: VeyraColors.cyan
                        )
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("VOORKEUREN")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(VeyraColors.secondary)

                        settingsCard(
                            .trakt,
                            status: trakt.isConnected ? "Verbonden" : "Niet gekoppeld",
                            statusColor: VeyraColors.cyan
                        )
                        settingsCard(.subtitles, status: "", statusColor: VeyraColors.cyan)
                        settingsCard(.metadata, status: "", statusColor: VeyraColors.cyan)
                        settingsCard(.shelves, status: "", statusColor: VeyraColors.cyan)
                        settingsCard(.account, status: "", statusColor: VeyraColors.cyan)
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

    // MARK: - Destination

    @ViewBuilder
    private func destinationView(_ destination: SettingsDestination) -> some View {
        switch destination {
        case .iptv: IPTVAccountsView()
        case .addons: AddonsSettingsView()
        case .mediaServers: MediaServersSettingsView()
        case .trakt: TraktSettingsView()
        case .subtitles: SubtitlePreferencesView()
        case .metadata: MetadataSettingsView()
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
