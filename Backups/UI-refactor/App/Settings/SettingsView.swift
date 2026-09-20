import SwiftUI
import Foundation

// MARK: - Addon change notification

extension Notification.Name {
    static let veyraAddonConfigurationDidChange =
        Notification.Name(
            "VeyraAddonConfigurationDidChange"
        )
}

// MARK: - Settings

@MainActor
struct SettingsView: View {
    @ObservedObject private var trakt = TraktStore.shared

    @State private var configuration: IPTVStoredConfiguration?
    @State private var errorMessage: String?
    @State private var destination: SettingsDestination?
    @State private var enabledAddonCount = 0

    @FocusState
    private var focusedRow: SettingsDestination?

    private let configurationStore =
        IPTVConfigurationStore()

    private let addonStore =
        AddonStore()

    var body: some View {
        ZStack {
            background

            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 36
                ) {
                    header
                    sourcesSection
                    accountSection
                    watchingSection
                    appSection
                    versionInformation
                }
                .frame(
                    maxWidth: 1180,
                    alignment: .leading
                )
                .padding(.horizontal, 70)
                .padding(.top, 50)
                .padding(.bottom, 70)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            AddonMigration()
                .runIfNeeded()

            loadConfiguration()
            loadAddonStatus()
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
        .navigationDestination(
            item: $destination
        ) { destination in
            switch destination {
            case .iptv:
                IPTVAccountsView()

            case .addons:
                VeyraAddonsSettingsView()

            case .trakt:
                TraktView()

            case .privacy:
                TraktPrivacyView()

            case .account:
                AccountView()
            }
        }
    }

    // MARK: - Background

    private var background: some View {
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
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack(
            alignment: .center,
            spacing: 22
        ) {
            RoundedRectangle(
                cornerRadius: 3
            )
            .fill(Color.cyan)
            .frame(
                width: 4,
                height: 66
            )
            .accessibilityHidden(true)

            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                Text("INSTELLINGEN")
                    .font(
                        .system(
                            size: 58,
                            weight: .light
                        )
                    )
                    .tracking(8)
                    .foregroundStyle(.white)

                Text(
                    "Beheer je bronnen, kijkprofiel en appgegevens."
                )
                .font(.system(size: 26))
                .foregroundStyle(
                    .white.opacity(0.62)
                )
            }

            Spacer()
        }
        .padding(.bottom, 8)
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        settingsGroup(
            number: "01",
            title: "BRONNEN"
        ) {
            settingsButton(
                destination: .iptv,
                icon: "tv",
                title: "IPTV",
                subtitle:
                    "Live TV en VOD via Xtream of M3U",
                status: iptvStatus,
                statusColor: iptvStatusColor
            )

            settingsButton(
                destination: .addons,
                icon: "puzzlepiece.extension",
                title: "Addons",
                subtitle:
                    "Streams via gekoppelde addons",
                status: addonsStatus,
                statusColor:
                    enabledAddonCount > 0
                    ? .cyan
                    : .white.opacity(0.60)
            )

            if let errorMessage {
                HStack(
                    alignment: .top,
                    spacing: 12
                ) {
                    Image(
                        systemName:
                            "exclamationmark.triangle"
                    )

                    Text(errorMessage)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
                .font(.system(size: 21))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        settingsGroup(
            number: "01A",
            title: "ACCOUNT"
        ) {
            settingsButton(
                destination: .account,
                icon: "person.crop.circle",
                title: "Account",
                subtitle:
                    "Beheer je profiel en accountinstellingen",
                status: "",
                statusColor: .cyan
            )
        }
    }

    // MARK: - Watching

    private var watchingSection: some View {
        settingsGroup(
            number: "02",
            title: "KIJKPROFIEL"
        ) {
            settingsButton(
                destination: .trakt,
                icon: "checkmark.circle",
                title: "Trakt",
                subtitle:
                    "Kijkgeschiedenis, voortgang en lijsten",
                status:
                    trakt.isConnected
                    ? "Verbonden"
                    : "Niet gekoppeld",
                statusColor:
                    trakt.isConnected
                    ? .cyan
                    : .white.opacity(0.60)
            )
        }
    }

    // MARK: - App

    private var appSection: some View {
        settingsGroup(
            number: "03",
            title: "APP & PRIVACY"
        ) {
            settingsButton(
                destination: .privacy,
                icon: "hand.raised",
                title: "Privacy en Trakt",
                subtitle:
                    "Uitleg over je koppeling en gedeelde kijkgegevens",
                status: "Informatie",
                statusColor:
                    .white.opacity(0.60)
            )
        }
    }

    // MARK: - Group

    private func settingsGroup<Content: View>(
        number: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            HStack(spacing: 14) {
                Text(number)
                    .font(
                        .system(
                            size: 21,
                            weight: .medium,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(
                        .cyan.opacity(0.65)
                    )

                Text(title)
                    .font(
                        .system(
                            size: 26,
                            weight: .semibold
                        )
                    )
                    .tracking(3)
                    .foregroundStyle(.cyan)

                Rectangle()
                    .fill(
                        Color.cyan.opacity(0.14)
                    )
                    .frame(height: 1)
                    .padding(.leading, 10)
            }
            .padding(.horizontal, 6)

            VStack(spacing: 12) {
                content()
            }
        }
    }

    // MARK: - Settings Button

    private func settingsButton(
        destination target: SettingsDestination,
        icon: String,
        title: String,
        subtitle: String,
        status: String,
        statusColor: Color
    ) -> some View {
        let isFocused =
            focusedRow == target

        return Button {
            destination = target
        } label: {
            HStack(spacing: 24) {
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
                        systemName: icon
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
                    Text(title)
                        .font(
                            .system(
                                size: 33,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(
                            .system(size: 22)
                        )
                        .foregroundStyle(
                            .white.opacity(
                                isFocused
                                ? 0.85
                                : 0.60
                            )
                        )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

                if !status.isEmpty {
                    Text(status)
                        .font(
                            .system(
                                size: 21,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            isFocused
                            ? .white
                            : statusColor
                        )
                        .padding(
                            .horizontal,
                            14
                        )
                        .padding(
                            .vertical,
                            8
                        )
                        .background(
                            Capsule()
                                .fill(
                                    isFocused
                                    ? Color.cyan
                                        .opacity(0.16)
                                    : statusColor
                                        .opacity(0.10)
                                )
                        )
                }

                Image(
                    systemName:
                        "chevron.right"
                )
                .font(
                    .system(
                        size: 22,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color.cyan.opacity(
                        isFocused
                        ? 1.0
                        : 0.55
                    )
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(
                maxWidth: .infinity,
                minHeight: 112,
                alignment: .leading
            )
        }
        .buttonStyle(
            VeyraSettingsCardStyle(
                isFocused: isFocused
            )
        )
        .focused(
            $focusedRow,
            equals: target
        )
        .focusEffectDisabled()
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
}

// MARK: - Settings destinations

private enum SettingsDestination:
    String,
    Identifiable,
    Hashable
{
    case iptv
    case addons
    case trakt
    case privacy
    case account

    var id: String {
        rawValue
    }
}

// MARK: - Addon overview

@MainActor
private struct VeyraAddonsSettingsView:
    View
{
    @State private var addons:
        [AddonManifest] = []

    @State private var selectedAddon:
        AddonManifest?

    @State private var pendingDeleteAddon:
        AddonManifest?

    @State private var showAddAddon =
        false

    @State private var errorMessage:
        String?

    @FocusState
    private var focusedAddonID:
        UUID?

    @FocusState
    private var focusedDeleteAddonID:
        UUID?

    @FocusState
    private var addButtonFocused:
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
                    spacing: 32
                ) {
                    header
                    addAddonButton
                    existingAddonsSection

                    if let errorMessage {
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
            AddonMigration()
                .runIfNeeded()

            reloadAddons()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(
                    for:
                        .veyraAddonConfigurationDidChange
                )
        ) { _ in
            reloadAddons()
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
                Text("ADDONS")
                    .font(
                        .system(
                            size: 58,
                            weight: .light
                        )
                    )
                    .tracking(8)
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

        if addons.isEmpty {
            emptyState
        } else {
            VStack(spacing: 12) {
                ForEach(addons) {
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
                    addonSubtitle(
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

    private func reloadAddons() {
        addons =
            store.load()
    }

    private func deletePendingAddon() {
        guard
            let addon =
                pendingDeleteAddon
        else {
            return
        }

        do {
            try store.remove(
                id: addon.id
            )

            pendingDeleteAddon = nil
            errorMessage = nil

            reloadAddons()

            notifyAddonChange()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    private func addonSubtitle(
        _ addon: AddonManifest
    ) -> String {
        let host =
            addon.baseURL.host
            ?? addon.baseURL
                .absoluteString

        switch addon.kind {
        case .aioStreams:
            return
                "AIOStreams · \(host)"
        }
    }
}

// MARK: - Add addon

@MainActor
private struct AddonAddView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @State private var name =
        "AIOStreams"

    @State private var baseURLText =
        ""

    @State private var isEnabled =
        true

    @State private var errorMessage:
        String?

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
                    Text(
                        "ADDON TOEVOEGEN"
                    )
                    .font(
                        .system(
                            size: 58,
                            weight: .light
                        )
                    )
                    .tracking(8)
                    .foregroundStyle(.white)

                    Text(
                        "Koppel AIOStreams als stream-addon."
                    )
                    .font(
                        .system(size: 26)
                    )
                    .foregroundStyle(
                        .white.opacity(0.62)
                    )

                    fieldTitle("NAAM")

                    TextField(
                        "AIOStreams",
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
                        "AIOSTREAMS BASIS-URL"
                    )

                    TextField(
                        "https://jouw-server.example",
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
                        "Gebruik dezelfde basis-URL die Veyra voorheen als AIOStreamsBaseURL gebruikte."
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
                .padding(70)
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
            "ADDON TOEVOEGEN"
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
        .focusable(true)
        .focused(
            $saveFocused
        )
        .focusEffectDisabled()
        .onTapGesture {
            save()
        }
    }

    private func save() {
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
            !trimmedName.isEmpty
        else {
            errorMessage =
                "Vul een naam in."
            return
        }

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

        let addon =
            AddonManifest(
                name: trimmedName,
                kind: .aioStreams,
                baseURL: url,
                isEnabled: isEnabled
            )

        do {
            try store.add(addon)

            notifyAddonChange()
            dismiss()
        } catch {
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
                    Text(
                        "ADDON BEWERKEN"
                    )
                    .font(
                        .system(
                            size: 58,
                            weight: .light
                        )
                    )
                    .tracking(8)
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

                    fieldTitle("TYPE")

                    Text("AIOStreams")
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
                                .green
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
                .padding(70)
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

        return Text("OPSLAAN")
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
            .focusable(true)
            .focused(
                $saveFocused
            )
            .focusEffectDisabled()
            .onTapGesture {
                save()
            }
    }

    private func save() {
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
            !trimmedName.isEmpty
        else {
            errorMessage =
                "Naam mag niet leeg zijn."
            return
        }

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

        manifest.name =
            trimmedName

        manifest.baseURL =
            url

        do {
            try store.update(
                manifest
            )

            saveMessage =
                "Addon opgeslagen."

            notifyAddonChange()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }
}

// MARK: - Account

@MainActor
private struct AccountView:
    View
{
    @AppStorage(
        "openSubtitlesEnabled"
    )
    private var openSubtitlesEnabled =
        false

    @FocusState
    private var subtitlesFocused:
        Bool

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
                    Text("ACCOUNT")
                        .font(
                            .system(
                                size: 58,
                                weight: .light
                            )
                        )
                        .tracking(8)
                        .foregroundStyle(
                            .white
                        )

                    Text(
                        "Beheer je profiel en accountinstellingen."
                    )
                    .font(
                        .system(size: 26)
                    )
                    .foregroundStyle(
                        .white.opacity(
                            0.62
                        )
                    )

                    openSubtitlesButton
                }
                .frame(
                    maxWidth: 900,
                    alignment: .leading
                )
                .padding(70)
            }
        }
    }

    private var openSubtitlesButton:
        some View
    {
        let focused =
            subtitlesFocused

        return HStack(spacing: 14) {
            Image(
                systemName:
                    openSubtitlesEnabled
                    ? "checkmark.circle.fill"
                    : "circle"
            )

            Text("OPENSUBTITLES")
                .font(
                    .system(
                        size: 22,
                        weight: .semibold
                    )
                )

            Spacer()

            Text(
                openSubtitlesEnabled
                ? "AAN"
                : "UIT"
            )
            .font(
                .system(
                    size: 21,
                    weight: .medium
                )
            )
            .foregroundStyle(
                focused
                ? .white
                : .cyan
            )
        }
        .foregroundStyle(.white)
        .padding(
            .horizontal,
            22
        )
        .padding(
            .vertical,
            18
        )
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                focused
                ? Color.cyan
                    .opacity(0.20)
                : Color.white
                    .opacity(0.05)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                focused
                ? Color.cyan
                : Color.cyan
                    .opacity(0.16),
                lineWidth:
                    focused
                    ? 2
                    : 1
            )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused(
            $subtitlesFocused
        )
        .focusEffectDisabled()
        .onTapGesture {
            openSubtitlesEnabled
                .toggle()
        }
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
            .background(
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(
                    isFocused
                    ? Color.cyan
                        .opacity(0.22)
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
                .stroke(
                    isFocused
                    ? Color.cyan
                        .opacity(0.80)
                    : Color.cyan
                        .opacity(0.12),
                    lineWidth:
                        isFocused
                        ? 2
                        : 1
                )
            )
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

private func notifyAddonChange() {
    NotificationCenter.default.post(
        name:
            .veyraAddonConfigurationDidChange,
        object: nil
    )
}

// MARK: - Theme

private enum VeyraSettingsTheme {
    static var background:
        some View
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
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
