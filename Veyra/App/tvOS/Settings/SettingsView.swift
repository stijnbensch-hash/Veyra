import SwiftUI
import Foundation

// MARK: - Settings

@MainActor
struct SettingsView: View {
    @ObservedObject private var trakt = TraktStore.shared

    @State private var configuration: IPTVStoredConfiguration?
    @State private var errorMessage: String?
    @State private var destination: SettingsDestination?
    @State private var mediaServerCount = 0
    @State private var categoryOrder: [SourceCategory] = SourceOrderDefaults.loadCategoryOrder()

    @FocusState
    private var focusedRow: SettingsDestination?

    private let configurationStore =
        IPTVConfigurationStore()

    private let mediaServerStore =
        MediaServerStore()

    var body: some View {
        VeyraDynamicBackgroundScope {
            ZStack {
                VeyraBackground().ignoresSafeArea()

                VeyraScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 44) {
                        header

                        settingsSection(title: "Weergave") {
                            settingsCard(destination: .home, icon: "house", title: "Home",
                                         subtitle: "Planken op het hoofdmenu", status: "", statusColor: VeyraColors.secondary)
                            settingsCard(destination: .subtitles, icon: "captions.bubble", title: "Ondertitels",
                                         subtitle: "Taal, OpenSubtitles en weergave", status: "", statusColor: VeyraColors.cyan)
                            settingsCard(destination: .general, icon: "gearshape", title: "Algemeen",
                                         subtitle: "Sport en favoriete teams", status: "", statusColor: VeyraColors.secondary)
                            settingsCard(destination: .playback, icon: "play.circle", title: "Afspelen",
                                         subtitle: "Resolutie, taal en oversla-segmenten", status: "", statusColor: VeyraColors.secondary)
                            settingsCard(destination: .metadata, icon: "star.leadinghalf.filled", title: "Metadata",
                                         subtitle: "Ratings op film- en seriepagina's", status: "", statusColor: VeyraColors.secondary)
                        }

                        settingsSection(title: "Bronnen") {
                            settingsCard(destination: .sourceAppearance, icon: "tag", title: "Bronverschijning",
                                         subtitle: "Badges in het bronkeuzescherm", status: "", statusColor: VeyraColors.secondary)

                            ForEach(categoryOrder) { category in
                                bronnenRow(for: category)
                            }
                        }

                        settingsSection(title: "Live TV") {
                            settingsCard(destination: .liveTVSettings, icon: "slider.horizontal.3", title: "Live TV instellingen",
                                         subtitle: "Gids, player, buffer en kanaalcache", status: "", statusColor: VeyraColors.secondary)
                        }

                        settingsSection(title: "Account") {
                            settingsCard(destination: .account, icon: "person.crop.circle", title: "Account",
                                         subtitle: "Trakt, ondertitels en profiel",
                                         status: trakt.isConnected ? "Trakt verbonden" : "Trakt niet gekoppeld",
                                         statusColor: trakt.isConnected ? VeyraColors.cyan : VeyraColors.secondary)
                        }

                        settingsSection(title: "Data") {
                            settingsCard(destination: .data, icon: "internaldrive", title: "Data",
                                         subtitle: "Cache legen, automatisch verversen, VeyraHub Recorder", status: "", statusColor: VeyraColors.secondary)
                        }

                        if let errorMessage {
                            Text(errorMessage).foregroundStyle(VeyraColors.red)
                        }

                        versionInformation
                        VeyraStreamingLogoAttribution()
                    }
                    .frame(maxWidth: 1300, alignment: .leading)
                    .padding(.horizontal, VeyraSpacing.page)
                    .padding(.top, 36)
                    .padding(.bottom, 60)
                    .frame(maxWidth: .infinity)
                }
            }
            .onAppear {
                loadConfiguration()
                loadMediaServerStatus()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .iptvConfigurationDidChange
                )
            ) { _ in
                loadConfiguration()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .veyraMediaServerConfigurationDidChange
                )
            ) { _ in
                loadMediaServerStatus()
            }
            .navigationDestination(
                item: $destination
            ) { destination in
                switch destination {
                case .iptv:
                    IPTVAccountsView()

                case .liveTVSettings:
                    IPTVPlaybackSettingsView()

                case .sourceAppearance:
                    SourceAppearanceView()

                case .mediaServers:
                    MediaServersSettingsView()

                case .account:
                    AccountView()
                case .subtitles:
                    SubtitlePreferencesView()
                case .subtitleAppearance:
                    SubtitleAppearanceSettingsView()
                case .general:
                    TVGeneralSettingsView()
                case .playback:
                    PlaybackSettingsView()
                case .metadata:
                    MetadataSettingsView()
                case .shelves:
                    ShelvesSettingsView()
                case .home:
                    VeyraHomeSettingsView()
                case .data:
                    DataSettingsView()
                }
            }

        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 22) {
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [VeyraColors.cyan, VeyraColors.red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 66)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 12) {
                Text("Instellingen")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Beheer je bronnen, kijkprofiel en appgegevens.")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()
        }
    }

    // MARK: - Section

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title.uppercased())
                .font(.system(size: 22, weight: .semibold))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.62))

            VStack(spacing: 18) {
                content()
            }
        }
    }

    // MARK: - Settings card

    private func settingsCard(
        destination target: SettingsDestination,
        icon: String,
        title: String,
        subtitle: String,
        status: String,
        statusColor: Color
    ) -> some View {
        Button {
            destination = target
        } label: {
            HStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(VeyraColors.cyan.opacity(0.14))

                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(VeyraColors.cyan)
                }
                .frame(width: 68, height: 68)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.60))

                    if !status.isEmpty {
                        Text(status)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(statusColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(VeyraColors.cyan.opacity(0.55))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .buttonStyle(VeyraFocusButtonStyle(radius: VeyraRadius.card))
    }

    // MARK: - Bronnen (categorievolgorde)

    /// Eén categorie in Bronnen, met omhoog/omlaag-knoppen om de
    /// categorievolgorde te herschikken — dezelfde SourceOrderDefaults-
    /// opslag als op iOS, alleen met tvOS-focusknoppen.
    @ViewBuilder
    private func bronnenRow(for category: SourceCategory) -> some View {
        switch category {
        case .iptv:
            reorderableRow(category) {
                settingsCard(destination: .iptv, icon: "tv", title: "IPTV",
                             subtitle: "Live TV en VOD via Xtream of M3U", status: iptvStatus, statusColor: iptvStatusColor)
            }
        case .addons:
            EmptyView() // Alleen voor opgeslagen categorievolgordes uit oudere builds.
        case .mediaServers:
            reorderableRow(category) {
                settingsCard(destination: .mediaServers, icon: "server.rack", title: "Mediaservers",
                             subtitle: "Jellyfin en andere eigen servers", status: mediaServersStatus, statusColor: VeyraColors.cyan)
            }
        }
    }

    private func reorderableRow(
        _ category: SourceCategory,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack(spacing: 14) {
            content()

            VStack(spacing: 10) {
                Button {
                    moveCategory(category, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 60, height: 44)
                }
                .buttonStyle(VeyraFocusButtonStyle(radius: 14))
                .disabled(categoryOrder.first == category)

                Button {
                    moveCategory(category, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 60, height: 44)
                }
                .buttonStyle(VeyraFocusButtonStyle(radius: 14))
                .disabled(categoryOrder.last == category)
            }
        }
    }

    private func moveCategory(_ category: SourceCategory, by offset: Int) {
        guard let index = categoryOrder.firstIndex(of: category) else { return }
        let destination = index + offset
        guard categoryOrder.indices.contains(destination) else { return }
        categoryOrder.swapAt(index, destination)
        SourceOrderDefaults.saveCategoryOrder(categoryOrder)
    }

    // MARK: - Version

    private var versionInformation:
        some View
    {
        HStack(spacing: 12) {
            Image(
                systemName: "info.circle"
            )
            .foregroundStyle(
                .cyan.opacity(0.65)
            )

            Text(versionText)
                .font(.system(size: 22))
                .foregroundStyle(
                    .white.opacity(0.50)
                )

            Spacer()
        }
    }

    private var versionText: String {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String
            ?? "Onbekend"

        let build =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleVersion"
            ) as? String
            ?? "Onbekend"

        return
            "Veyra \(version) · Build \(build)"
    }

    // MARK: - Status

    private var mediaServersStatus: String {
        switch mediaServerCount {
        case 0:
            return "Niet gekoppeld"

        case 1:
            return "1 gekoppeld"

        default:
            return "\(mediaServerCount) gekoppeld"
        }
    }

    private var iptvStatus: String {
        if errorMessage != nil {
            return "Controle mislukt"
        }

        guard let configuration else {
            return "Niet ingesteld"
        }

        switch configuration {
        case .m3u:
            return "M3U"

        case .xtream:
            return "Xtream"
        }
    }

    private var iptvStatusColor: Color {
        if errorMessage != nil {
            return .orange
        }

        return configuration == nil
            ? .white.opacity(0.60)
            : .cyan
    }

    private func loadConfiguration() {
        do {
            configuration =
                try configurationStore.load()

            errorMessage = nil
        } catch {
            configuration = nil
            errorMessage =
                error.localizedDescription
        }
    }

    private func loadMediaServerStatus() {
        mediaServerCount =
            mediaServerStore
                .load()
                .count
    }
}

// MARK: - Settings destinations

private enum SettingsDestination:
    String,
    Identifiable,
    Hashable
{
    case iptv
    case liveTVSettings
    case sourceAppearance
    case mediaServers
    case account
    case subtitles
    case subtitleAppearance
    case general
    case playback
    case metadata
    case shelves
    case home
    case data

    var id: String {
        rawValue
    }
}

// MARK: - Account

@MainActor
struct AccountView:
    View
{
    @ObservedObject private var trakt = TraktStore.shared

    var body: some View {
        ZStack {
            VeyraSettingsTheme.background

            VeyraList {
                Section {
                    NavigationLink {
                        TraktView()
                    } label: {
                        VeyraSettingsCardRowLabel(
                            icon: "checkmark.circle",
                            title: trakt.isConnected ? "Trakt — verbonden" : "Trakt — niet gekoppeld"
                        ) {
                            VeyraSettingsCardRowValue(value: nil)
                        }
                    }
                    .veyraCardRow()

                    NavigationLink {
                        TraktPrivacyView()
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "hand.raised", title: "Privacy en gedeelde kijkgegevens") {
                            VeyraSettingsCardRowValue(value: nil)
                        }
                    }
                    .veyraCardRow()
                } header: {
                    Text("Trakt-account")
                }

                Section {
                    OpenSubtitlesConfigurationCard()
                } header: {
                    Text("Ondertitels")
                }

                Section {
                    FanartConfigurationCard()
                } header: {
                    Text("fanart.tv")
                } footer: {
                    Text("Optioneel: echte banners in de kleine Verder kijken-kaartjes op Home.")
                }

                Section {
                    MDBListConfigurationCard()
                } header: {
                    Text("MDBList")
                } footer: {
                    Text("Popcornmeter en Letterboxd komen via MDBList (mdblist.com). Vul hier een gratis API-sleutel in om die twee scores te tonen bij Instellingen → Metadata → Ratings.")
                }

                Section {
                    IntroDBConfigurationCard()
                } header: {
                    Text("TheIntroDB")
                } footer: {
                    Text("Voor \"Intro overslaan\" tijdens het afspelen. Een gratis API-sleutel (theintrodb.org) geeft een hoger limiet en betere matching dan anoniem gebruik.")
                }

            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Account")
    }

}

// MARK: - Settings card style

private struct VeyraSettingsCardStyle:
    ButtonStyle
{
    let isFocused: Bool

    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .veyraGlass(radius: VeyraRadius.card)
            .overlay {
                RoundedRectangle(cornerRadius: VeyraRadius.card)
                    .stroke(isFocused ? VeyraColors.cyan : .clear, lineWidth: 2)
            }
            .opacity(
                configuration.isPressed
                ? 0.85
                : 1
            )
    }
}

// MARK: - Theme

private enum VeyraSettingsTheme {
    static var background:
        some View
    {
        VeyraBackground()
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
