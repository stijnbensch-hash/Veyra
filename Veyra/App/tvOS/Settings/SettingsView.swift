import SwiftUI
import Foundation

// MARK: - Settings

@MainActor
struct SettingsView: View {
    @ObservedObject private var trakt = TraktStore.shared
    @ObservedObject private var cloudSync = CloudSettingsSync.shared

    @State private var configuration: IPTVStoredConfiguration?
    @State private var errorMessage: String?
    @State private var destination: SettingsDestination?
    @State private var enabledAddonCount = 0
    @State private var mediaServerCount = 0
    @State private var categoryOrder: [SourceCategory] = SourceOrderDefaults.loadCategoryOrder()

    @FocusState
    private var focusedRow: SettingsDestination?

    private let configurationStore =
        IPTVConfigurationStore()

    private let addonStore =
        AddonStore()

    private let mediaServerStore =
        MediaServerStore()

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 44) {
                    header

                    settingsSection(title: "Live TV") {
                        settingsCard(destination: .liveTVSettings, icon: "slider.horizontal.3", title: "Live TV instellingen",
                                     subtitle: "Gids, player, buffer en kanaalcache", status: "", statusColor: VeyraColors.secondary)
                    }

                    settingsSection(title: "Bronnen") {
                        ForEach(categoryOrder) { category in
                            bronnenRow(for: category)
                        }
                    }

                    settingsSection(title: "Weergave") {
                        settingsCard(destination: .subtitles, icon: "captions.bubble", title: "Ondertitels",
                                     subtitle: "Standaardtaal en OpenSubtitles", status: "", statusColor: VeyraColors.cyan)
                        settingsCard(destination: .subtitleAppearance, icon: "textformat.size", title: "Ondertitelweergave",
                                     subtitle: "Grootte, plaatsing, achtergrond", status: "", statusColor: VeyraColors.secondary)
                        settingsCard(destination: .playback, icon: "play.circle", title: "Afspelen",
                                     subtitle: "Resolutie, taal en oversla-segmenten", status: "", statusColor: VeyraColors.secondary)
                        settingsCard(destination: .metadata, icon: "star.leadinghalf.filled", title: "Metadata",
                                     subtitle: "Ratings op film- en seriepagina's", status: "", statusColor: VeyraColors.secondary)
                        settingsCard(destination: .shelves, icon: "rectangle.grid.1x2", title: "Planken",
                                     subtitle: "Eigen rijen op het hoofdmenu", status: "", statusColor: VeyraColors.secondary)
                    }

                    settingsSection(title: "Account") {
                        settingsCard(destination: .account, icon: "person.crop.circle", title: "Account",
                                     subtitle: "Trakt, ondertitels en profiel",
                                     status: trakt.isConnected ? "Trakt verbonden" : "Trakt niet gekoppeld",
                                     statusColor: trakt.isConnected ? VeyraColors.cyan : VeyraColors.secondary)
                        settingsCard(destination: .cloudSync, icon: "icloud", title: "Gegevens en opslag",
                                     subtitle: "iCloud-synchronisatie en opslaggebruik",
                                     status: cloudSync.isEnabled ? "Aan" : "Uit",
                                     statusColor: cloudSync.isEnabled ? VeyraColors.cyan : VeyraColors.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(VeyraColors.red)
                    }

                    versionInformation
                }
                .frame(maxWidth: 1300, alignment: .leading)
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            AddonMigration()
                .runIfNeeded()

            loadConfiguration()
            loadAddonStatus()
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
                for: .veyraAddonConfigurationDidChange
            )
        ) { _ in
            loadAddonStatus()
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

            case .addons:
                VeyraAddonsSettingsView()

            case .mediaServers:
                MediaServersSettingsView()

            case .account:
                AccountView()
            case .subtitles:
                SubtitlePreferencesView()
            case .subtitleAppearance:
                SubtitleAppearanceSettingsView()
            case .playback:
                PlaybackSettingsView()
            case .metadata:
                MetadataSettingsView()
            case .shelves:
                ShelvesSettingsView()
            case .cloudSync:
                CloudSyncSettingsView()
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
            reorderableRow(category) {
                settingsCard(destination: .addons, icon: "puzzlepiece.extension", title: "Addons",
                             subtitle: "Streams via gekoppelde addons", status: addonsStatus, statusColor: VeyraColors.cyan)
            }
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

    private var addonsStatus: String {
        switch enabledAddonCount {
        case 0:
            return "Niet ingesteld"

        case 1:
            return "1 actief"

        default:
            return "\(enabledAddonCount) actief"
        }
    }

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

    private func loadAddonStatus() {
        enabledAddonCount =
            addonStore
                .enabledAddons()
                .count
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
    case addons
    case mediaServers
    case account
    case subtitles
    case subtitleAppearance
    case playback
    case metadata
    case shelves
    case cloudSync

    var id: String {
        rawValue
    }
}

// MARK: - Addon overview

@MainActor
struct VeyraAddonsSettingsView:
    View
{
    @State private var selectedAddon:
        AddonManifest?

    @State private var pendingDeleteAddon:
        AddonManifest?

    @State private var showAddAddon =
        false

    @FocusState
    private var focusedAddonID:
        UUID?

    @FocusState
    private var focusedDeleteAddonID:
        UUID?

    @FocusState
    private var addButtonFocused:
        Bool

    @StateObject private var viewModel = AddonsViewModel()

    var body: some View {
        ZStack {
            VeyraSettingsTheme.background

            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 32
                ) {
                    header
                    addAddonButton
                    existingAddonsSection

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(
                                .system(size: 20)
                            )
                            .foregroundStyle(
                                .orange
                            )
                    }
                }
                .frame(
                    maxWidth: 1180,
                    alignment: .leading
                )
                .padding(
                    .horizontal,
                    70
                )
                .padding(
                    .top,
                    50
                )
                .padding(
                    .bottom,
                    70
                )
                .frame(
                    maxWidth: .infinity
                )
            }
        }
        .onAppear {
            viewModel.runMigrationIfNeeded()
            viewModel.reload()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(
                    for:
                        .veyraAddonConfigurationDidChange
                )
        ) { _ in
            viewModel.reload()
        }
        .navigationDestination(
            item: $selectedAddon
        ) { addon in
            AddonEditView(
                manifest: addon
            )
        }
        .navigationDestination(
            isPresented:
                $showAddAddon
        ) {
            AddonAddView()
        }
        .confirmationDialog(
            "Koppeling verwijderen?",
            isPresented:
                deleteDialogBinding,
            titleVisibility:
                .visible
        ) {
            Button(
                "Verwijderen",
                role: .destructive
            ) {
                deletePendingAddon()
            }

            Button(
                "Annuleren",
                role: .cancel
            ) {
                pendingDeleteAddon = nil
            }
        } message: {
            if let addon =
                pendingDeleteAddon
            {
                Text(
                    "\(addon.name) wordt uit Veyra verwijderd."
                )
            }
        }
    }

    private var deleteDialogBinding:
        Binding<Bool>
    {
        Binding(
            get: {
                pendingDeleteAddon
                    != nil
            },
            set: { value in
                if !value {
                    pendingDeleteAddon =
                        nil
                }
            }
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 22) {
            RoundedRectangle(
                cornerRadius: 3
            )
            .fill(Color.cyan)
            .frame(
                width: 4,
                height: 66
            )

            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                Text("Addons")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(
                    "Je stream-addons in Veyra."
                )
                .font(.system(size: 26))
                .foregroundStyle(
                    .white.opacity(0.62)
                )
            }

            Spacer()
        }
    }

    // MARK: - Add button

    private var addAddonButton:
        some View
    {
        let focused =
            addButtonFocused

        return HStack(spacing: 12) {
            Image(
                systemName: "plus"
            )

            Text(
                "ADDON TOEVOEGEN"
            )
            .font(
                .system(
                    size: 22,
                    weight: .semibold
                )
            )
            .tracking(2)
        }
        .foregroundStyle(
            focused
            ? .white
            : .cyan
        )
        .padding(
            .horizontal,
            22
        )
        .padding(
            .vertical,
            14
        )
        .background(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(
                focused
                ? Color.cyan
                    .opacity(0.24)
                : Color.cyan
                    .opacity(0.10)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .strokeBorder(
                focused
                ? Color.cyan
                : Color.cyan
                    .opacity(0.25),
                lineWidth:
                    focused
                    ? 2
                    : 1
            )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused(
            $addButtonFocused
        )
        .focusEffectDisabled()
        .onTapGesture {
            showAddAddon = true
        }
    }

    // MARK: - Existing addons

    @ViewBuilder
    private var existingAddonsSection:
        some View
    {
        Text(
            "BESTAANDE KOPPELINGEN"
        )
        .font(
            .system(
                size: 26,
                weight: .semibold
            )
        )
        .tracking(3)
        .foregroundStyle(.cyan)

        if viewModel.addons.isEmpty {
            emptyState
        } else {
            VStack(spacing: 12) {
                ForEach(viewModel.addons) {
                    addon in

                    addonRow(addon)
                }
            }
        }
    }

    private func addonRow(
        _ addon: AddonManifest
    ) -> some View {
        HStack(
            alignment: .center,
            spacing: 14
        ) {
            addonMainControl(addon)
            addonDeleteControl(addon)
        }
    }

    // MARK: - Main addon control

    private func addonMainControl(
        _ addon: AddonManifest
    ) -> some View {
        let isFocused =
            focusedAddonID
                == addon.id

        return HStack(
            alignment: .center,
            spacing: 24
        ) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    Color.cyan.opacity(
                        isFocused
                        ? 0.20
                        : 0.10
                    )
                )

                Image(
                    systemName:
                        "puzzlepiece.extension"
                )
                .font(
                    .system(
                        size: 39,
                        weight: .light
                    )
                )
                .foregroundStyle(
                    isFocused
                    ? .white
                    : .cyan
                )
            }
            .frame(
                width: 68,
                height: 68
            )

            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                HStack(spacing: 12) {
                    Text(addon.name)
                        .font(
                            .system(
                                size: 32,
                                weight:
                                    .semibold
                            )
                        )
                        .foregroundStyle(
                            .white
                        )

                    Text(
                        addon.isEnabled
                        ? "ACTIEF"
                        : "UIT"
                    )
                    .font(
                        .system(
                            size: 16,
                            weight: .bold
                        )
                    )
                    .tracking(1)
                    .foregroundStyle(
                        addon.isEnabled
                        ? .cyan
                        : .secondary
                    )
                }

                Text(
                    viewModel.subtitle(
                        for:
                        addon
                    )
                )
                .font(
                    .system(size: 21)
                )
                .foregroundStyle(
                    .white.opacity(
                        isFocused
                        ? 0.85
                        : 0.62
                    )
                )
                .lineLimit(1)
            }

            Spacer()

            Text("Details")
                .font(
                    .system(
                        size: 21,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    isFocused
                    ? .white
                    : .cyan
                )

            Image(
                systemName:
                    "chevron.right"
            )
            .font(
                .system(
                    size: 21,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                isFocused
                ? .white
                : .cyan.opacity(0.60)
            )
        }
        .padding(24)
        .frame(
            maxWidth: .infinity,
            minHeight: 116,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(
                isFocused
                ? Color.cyan
                    .opacity(0.18)
                : Color(
                    red: 0.03,
                    green: 0.09,
                    blue: 0.14
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                ? Color.cyan
                : Color.cyan
                    .opacity(0.12),
                lineWidth:
                    isFocused
                    ? 2
                    : 1
            )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused(
            $focusedAddonID,
            equals: addon.id
        )
        .focusEffectDisabled()
        .onTapGesture {
            selectedAddon =
                addon
        }
    }

    // MARK: - Delete

    private func addonDeleteControl(
        _ addon: AddonManifest
    ) -> some View {
        let isFocused =
            focusedDeleteAddonID
                == addon.id

        return VStack(spacing: 8) {
            Image(
                systemName: "trash"
            )
            .font(
                .system(
                    size: 32,
                    weight: .medium
                )
            )

            Text("VERWIJDER")
                .font(
                    .system(
                        size: 18,
                        weight: .semibold
                    )
                )
                .tracking(1)
        }
        .foregroundStyle(
            isFocused
            ? .white
            : .red.opacity(0.85)
        )
        .frame(
            width: 130,
            height: 116
        )
        .background(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(
                isFocused
                ? Color.red
                    .opacity(0.20)
                : Color(
                    red: 0.03,
                    green: 0.09,
                    blue: 0.14
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                ? Color.red
                : Color.red
                    .opacity(0.25),
                lineWidth:
                    isFocused
                    ? 2
                    : 1
            )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused(
            $focusedDeleteAddonID,
            equals: addon.id
        )
        .focusEffectDisabled()
        .onTapGesture {
            pendingDeleteAddon =
                addon
        }
    }

    // MARK: - Empty

    private var emptyState:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            Text(
                "Geen addonverbindingen"
            )
            .font(
                .system(
                    size: 32,
                    weight: .semibold
                )
            )
            .foregroundStyle(.white)

            Text(
                "Voeg een addon toe om streams via deze bron te laden."
            )
            .font(
                .system(size: 22)
            )
            .foregroundStyle(
                .white.opacity(0.62)
            )
        }
        .padding(24)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(
                Color(
                    red: 0.03,
                    green: 0.09,
                    blue: 0.14
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                Color.cyan.opacity(
                    0.12
                ),
                lineWidth: 1
            )
        )
    }

    // MARK: - Data

    private func deletePendingAddon() {
        guard let addon = pendingDeleteAddon else {
            return
        }

        viewModel.remove(addon)
        pendingDeleteAddon = nil
    }
}

// MARK: - Add addon

@MainActor
private struct AddonAddView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    // Geen "Type"-keuze meer: elke Stremio-compatibele addon beschrijft
    // zelf via zijn manifest.json wat voor addon hij is — zie
    // Shared/Addons/StremioManifestFetcher.swift.
    @State private var name =
        ""

    @State private var baseURLText =
        ""

    @State private var isEnabled =
        true

    @State private var errorMessage:
        String?

    @State private var isFetchingManifest =
        false

    @State private var manifestNamePlaceholder =
        ""

    @FocusState
    private var saveFocused:
        Bool

    private let store =
        AddonStore()

    var body: some View {
        ZStack {
            VeyraSettingsTheme.background

            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {
                    Text("Addon toevoegen")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                    Text(
                        "Koppel een addon via zijn manifest-URL."
                    )
                    .font(
                        .system(size: 26)
                    )
                    .foregroundStyle(
                        .white.opacity(0.62)
                    )

                    fieldTitle("NAAM (OPTIONEEL)")

                    TextField(
                        manifestNamePlaceholder.isEmpty ? "Overgenomen uit het manifest" : manifestNamePlaceholder,
                        text: $name
                    )
                    .textFieldStyle(.plain)
                    .font(
                        .system(size: 22)
                    )
                    .padding(18)
                    .background(
                        inputBackground
                    )

                    fieldTitle(
                        "MANIFEST-URL"
                    )

                    TextField(
                        "https://jouw-server.example/manifest.json",
                        text: $baseURLText
                    )
                    .textFieldStyle(.plain)
                    .font(
                        .system(
                            size: 21,
                            design:
                                .monospaced
                        )
                    )
                    .padding(18)
                    .background(
                        inputBackground
                    )

                    Text(
                        "Naam en type (streaming of metadata) worden automatisch uit het manifest gehaald."
                    )
                    .font(
                        .system(size: 18)
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Toggle(
                        "Addon actief",
                        isOn: $isEnabled
                    )
                    .font(
                        .system(size: 22)
                    )
                    .tint(.cyan)

                    if let errorMessage {
                        Text(
                            errorMessage
                        )
                        .font(
                            .system(size: 20)
                        )
                        .foregroundStyle(
                            .orange
                        )
                    }

                    saveButton
                }
                .frame(
                    maxWidth: 900,
                    alignment: .leading
                )
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 50)
            }
        }
    }

    private func fieldTitle(
        _ title: String
    ) -> some View {
        Text(title)
            .font(
                .system(
                    size: 18,
                    weight: .semibold
                )
            )
            .tracking(2)
            .foregroundStyle(.cyan)
    }

    private var inputBackground:
        some View
    {
        RoundedRectangle(
            cornerRadius: 14,
            style: .continuous
        )
        .fill(
            Color.white.opacity(0.06)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                Color.cyan.opacity(0.18),
                lineWidth: 1
            )
        )
    }

    private var saveButton:
        some View
    {
        let focused =
            saveFocused

        return Text(
            isFetchingManifest
            ? "BEZIG..."
            : "ADDON TOEVOEGEN"
        )
        .font(
            .system(
                size: 21,
                weight: .semibold
            )
        )
        .tracking(2)
        .foregroundStyle(
            focused
            ? .white
            : .cyan
        )
        .padding(
            .horizontal,
            24
        )
        .padding(
            .vertical,
            15
        )
        .background(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(
                focused
                ? Color.cyan
                    .opacity(0.24)
                : Color.cyan
                    .opacity(0.10)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                focused
                ? Color.cyan
                : Color.cyan
                    .opacity(0.25),
                lineWidth:
                    focused
                    ? 2
                    : 1
            )
        )
        .contentShape(Rectangle())
        .focusable(!isFetchingManifest)
        .focused(
            $saveFocused
        )
        .focusEffectDisabled()
        .onTapGesture {
            guard !isFetchingManifest else { return }
            Task { await save() }
        }
    }

    private func save() async {
        errorMessage = nil

        let trimmedName =
            name.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        let trimmedURL =
            baseURLText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            let url =
                validatedAddonURL(
                    trimmedURL
                )
        else {
            errorMessage =
                "Vul een geldige HTTP(S)-URL in."
            return
        }

        isFetchingManifest = true

        let kind: AddonKind
        var finalName = trimmedName

        do {
            let fetched = try await StremioManifestFetcher.fetch(from: url)
            kind = fetched.kind
            manifestNamePlaceholder = fetched.name
            if finalName.isEmpty {
                finalName = fetched.name
            }
        } catch {
            isFetchingManifest = false
            errorMessage =
                (error as? LocalizedError)?.errorDescription
                ?? "Kon het manifest niet ophalen."
            return
        }

        guard !finalName.isEmpty else {
            isFetchingManifest = false
            errorMessage =
                "Kon geen naam uit het manifest halen — vul zelf een naam in."
            return
        }

        let addon =
            AddonManifest(
                name: finalName,
                kind: kind,
                baseURL: url,
                isEnabled: isEnabled
            )

        do {
            try store.add(addon)

            isFetchingManifest = false
            notifyAddonChange()
            dismiss()
        } catch {
            isFetchingManifest = false
            errorMessage =
                error.localizedDescription
        }
    }
}

// MARK: - Edit addon

@MainActor
private struct AddonEditView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @State private var manifest:
        AddonManifest

    @State private var baseURLText:
        String

    @State private var errorMessage:
        String?

    @State private var saveMessage:
        String?

    @State private var isFetchingManifest =
        false

    @FocusState
    private var saveFocused:
        Bool

    private let store =
        AddonStore()

    init(
        manifest: AddonManifest
    ) {
        _manifest =
            State(
                initialValue:
                    manifest
            )

        _baseURLText =
            State(
                initialValue:
                    manifest
                        .baseURL
                        .absoluteString
            )
    }

    var body: some View {
        ZStack {
            VeyraSettingsTheme.background

            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {
                    Text("Addon bewerken")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                    Text(
                        "Beheer de streamverbinding van deze addon."
                    )
                    .font(
                        .system(size: 26)
                    )
                    .foregroundStyle(
                        .white.opacity(0.62)
                    )

                    fieldTitle("TYPE (AUTOMATISCH)")

                    Text(
                        manifest.kind == .aioStreams
                            ? "AIOStreams"
                            : manifest.kind == .torrent ? "Torrent" : "AIOMetadata"
                    )
                        .font(
                            .system(
                                size: 22,
                                weight:
                                    .semibold
                            )
                        )
                        .foregroundStyle(
                            .cyan
                        )

                    Text(
                        "Wordt opnieuw uit het manifest gehaald bij het opslaan."
                    )
                    .font(
                        .system(size: 18)
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    fieldTitle("NAAM")

                    TextField(
                        "Naam",
                        text:
                            $manifest.name
                    )
                    .textFieldStyle(.plain)
                    .font(
                        .system(size: 22)
                    )
                    .padding(18)
                    .background(
                        inputBackground
                    )

                    fieldTitle(
                        "BASIS-URL"
                    )

                    TextField(
                        "https://...",
                        text:
                            $baseURLText
                    )
                    .textFieldStyle(.plain)
                    .font(
                        .system(
                            size: 21,
                            design:
                                .monospaced
                        )
                    )
                    .padding(18)
                    .background(
                        inputBackground
                    )

                    Toggle(
                        "Addon actief",
                        isOn:
                            $manifest
                                .isEnabled
                    )
                    .font(
                        .system(size: 22)
                    )
                    .tint(.cyan)

                    if let saveMessage {
                        Text(saveMessage)
                            .font(
                                .system(
                                    size: 20
                                )
                            )
                            .foregroundStyle(
                                VeyraColors.cyan
                            )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(
                                .system(
                                    size: 20
                                )
                            )
                            .foregroundStyle(
                                .orange
                            )
                    }

                    saveButton
                }
                .frame(
                    maxWidth: 900,
                    alignment: .leading
                )
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 50)
            }
        }
    }

    private func fieldTitle(
        _ title: String
    ) -> some View {
        Text(title)
            .font(
                .system(
                    size: 18,
                    weight: .semibold
                )
            )
            .tracking(2)
            .foregroundStyle(.cyan)
    }

    private var inputBackground:
        some View
    {
        RoundedRectangle(
            cornerRadius: 14,
            style: .continuous
        )
        .fill(
            Color.white.opacity(0.06)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                Color.cyan.opacity(0.18),
                lineWidth: 1
            )
        )
    }

    private var saveButton:
        some View
    {
        let focused =
            saveFocused

        return Text(
            isFetchingManifest
            ? "BEZIG..."
            : "OPSLAAN"
        )
            .font(
                .system(
                    size: 21,
                    weight: .semibold
                )
            )
            .tracking(2)
            .foregroundStyle(
                focused
                ? .white
                : .cyan
            )
            .padding(
                .horizontal,
                24
            )
            .padding(
                .vertical,
                15
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    focused
                    ? Color.cyan
                        .opacity(0.24)
                    : Color.cyan
                        .opacity(0.10)
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    focused
                    ? Color.cyan
                    : Color.cyan
                        .opacity(0.25),
                    lineWidth:
                        focused
                        ? 2
                        : 1
                )
            )
            .contentShape(Rectangle())
            .focusable(!isFetchingManifest)
            .focused(
                $saveFocused
            )
            .focusEffectDisabled()
            .onTapGesture {
                guard !isFetchingManifest else { return }
                Task { await save() }
            }
    }

    private func save() async {
        errorMessage = nil
        saveMessage = nil

        let trimmedName =
            manifest.name
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let trimmedURL =
            baseURLText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            let url =
                validatedAddonURL(
                    trimmedURL
                )
        else {
            errorMessage =
                "Vul een geldige HTTP(S)-URL in."
            return
        }

        isFetchingManifest = true

        var finalName = trimmedName

        do {
            let fetched = try await StremioManifestFetcher.fetch(from: url)
            manifest.kind = fetched.kind
            if finalName.isEmpty {
                finalName = fetched.name
            }
        } catch {
            isFetchingManifest = false
            errorMessage =
                (error as? LocalizedError)?.errorDescription
                ?? "Kon het manifest niet ophalen."
            return
        }

        guard !finalName.isEmpty else {
            isFetchingManifest = false
            errorMessage =
                "Kon geen naam uit het manifest halen — vul zelf een naam in."
            return
        }

        manifest.name =
            finalName

        manifest.baseURL =
            url

        do {
            try store.update(
                manifest
            )

            isFetchingManifest = false
            saveMessage =
                "Addon opgeslagen."

            notifyAddonChange()
        } catch {
            isFetchingManifest = false
            errorMessage =
                error.localizedDescription
        }
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

            List {
                Section {
                    NavigationLink {
                        TraktView()
                    } label: {
                        Label(
                            trakt.isConnected ? "Trakt — verbonden" : "Trakt — niet gekoppeld",
                            systemImage: "checkmark.circle"
                        )
                    }

                    NavigationLink {
                        TraktPrivacyView()
                    } label: {
                        Label("Privacy en gedeelde kijkgegevens", systemImage: "hand.raised")
                    }
                } header: {
                    Text("Trakt-account")
                }

                Section {
                    OpenSubtitlesConfigurationCard()

                    NavigationLink {
                        SubtitlePreferencesView()
                    } label: {
                        Label("Taal en ondertitelvoorkeuren", systemImage: "captions.bubble")
                    }
                } header: {
                    Text("Ondertitels")
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

// MARK: - Shared addon helpers

private func validatedAddonURL(
    _ value: String
) -> URL? {
    guard
        var components =
            URLComponents(
                string: value
            ),
        let scheme =
            components.scheme?
                .lowercased(),
        scheme == "http"
            || scheme == "https",
        components.host != nil
    else {
        return nil
    }

    components.fragment = nil

    return components.url
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
