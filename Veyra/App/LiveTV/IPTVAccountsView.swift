import SwiftUI

struct IPTVAccountsView: View {
    @State private var providers:
        [IPTVStoredProvider] = []

    @State private var isLoading = false

    @State private var refreshingProviderIDs:
        Set<UUID> = []

    @State private var refreshMessages:
        [UUID: String] = [:]

    @State private var providerErrors:
        [UUID: String] = [:]

    @State private var errorMessage: String?

    private let configurationStore =
        IPTVConfigurationStore()

    private let service =
        IPTVService()

    var body: some View {
        ZStack {
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
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 24
            ) {
                header

                if isLoading &&
                    providers.isEmpty
                {
                    loadingView
                } else if
                    let errorMessage,
                    providers.isEmpty
                {
                    errorView(
                        errorMessage
                    )
                } else if providers.isEmpty {
                    emptyView
                } else {
                    providerList
                }
            }
            .padding(70)
        }
        .onAppear {
            loadProviders()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for:
                    .iptvConfigurationDidChange
            )
        ) { _ in
            loadProviders()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("IPTV")
                .font(
                    .system(
                        size: 54,
                        weight: .light
                    )
                )
                .tracking(12)
                .foregroundStyle(.white)

            Text("PROVIDERS")
                .font(.caption)
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )

            Text(
                providerCountLabel
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.top, 6)
        }
    }

    // MARK: - Provider List

    private var providerList: some View {
        ScrollView(.vertical) {
            LazyVStack(
                alignment: .leading,
                spacing: 18
            ) {
                addProviderButton

                ForEach(providers) {
                    provider in

                    providerCard(
                        provider
                    )
                }
            }
            .frame(
                maxWidth: 850,
                alignment: .leading
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
        }
        .focusSection()
    }

    // MARK: - Add Provider

    private var addProviderButton: some View {
        NavigationLink {
            IPTVSetupView(
                createsNewProvider: true
            )
        } label: {
            HStack(spacing: 8) {
                Image(
                    systemName: "plus"
                )

                Text("IPTV TOEVOEGEN")
            }
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Provider Card

    private func providerCard(
        _ provider:
            IPTVStoredProvider
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            HStack(
                alignment: .center,
                spacing: 20
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    Text(
                        provider.displayName
                    )
                    .font(
                        .system(
                            size: 26,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)

                    Text(
                        providerTypeLabel(
                            provider.configuration
                        )
                    )
                    .font(.caption)
                    .tracking(3)
                    .foregroundStyle(
                        .cyan.opacity(0.85)
                    )
                }

                Spacer()

                providerActions(
                    provider
                )
            }

            Divider()
                .overlay(
                    Color.white.opacity(
                        0.15
                    )
                )

            providerDetails(
                provider.configuration
            )

            if
                let message =
                    refreshMessages[
                        provider.id
                    ]
            {
                Label(
                    message,
                    systemImage:
                        "checkmark.circle"
                )
                .font(.callout)
                .foregroundStyle(
                    .cyan.opacity(0.85)
                )
            }

            if
                let message =
                    providerErrors[
                        provider.id
                    ]
            {
                Label(
                    message,
                    systemImage:
                        "exclamationmark.triangle"
                )
                .font(.callout)
                .foregroundStyle(.red)
            }
        }
        .padding(22)
        .frame(
            maxWidth: 850,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 18
            )
            .fill(
                Color.white.opacity(
                    0.06
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18
            )
            .stroke(
                Color.cyan.opacity(
                    0.18
                ),
                lineWidth: 1
            )
        )
        .focusSection()
    }

    // MARK: - Actions

    private func providerActions(
        _ provider:
            IPTVStoredProvider
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                Task {
                    await refreshProvider(
                        provider
                    )
                }
            } label: {
                HStack(spacing: 5) {
                    if refreshingProviderIDs
                        .contains(
                            provider.id
                        )
                    {
                        ProgressView()
                    } else {
                        Image(
                            systemName:
                                "arrow.clockwise"
                        )
                    }

                    Text(
                        refreshingProviderIDs
                            .contains(
                                provider.id
                            )
                            ? "LADEN…"
                            : "VERVERSEN"
                    )
                    .lineLimit(1)
                }
                .font(
                    .system(
                        size: 16,
                        weight: .semibold
                    )
                )
                .frame(width: 120)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .opacity(
                refreshingProviderIDs
                    .contains(
                        provider.id
                    )
                    ? 0.65
                    : 1.0
            )

            NavigationLink {
                IPTVProviderManagementLauncherView(
                    providerID:
                        provider.id
                )
            } label: {
                Text("BEHEREN")
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold
                        )
                    )
                    .lineLimit(1)
                    .frame(width: 120)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            NavigationLink {
                IPTVSetupView(
                    providerID:
                        provider.id
                )
            } label: {
                Text("BEWERKEN")
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold
                        )
                    )
                    .lineLimit(1)
                    .frame(width: 120)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .focusSection()
    }

    // MARK: - Provider Details

    @ViewBuilder
    private func providerDetails(
        _ configuration:
            IPTVStoredConfiguration
    ) -> some View {
        switch configuration {
        case .xtream(
            let configuration
        ):
            HStack(
                alignment: .top,
                spacing: 40
            ) {
                detailRow(
                    title: "TYPE",
                    value: "Xtream"
                )

                detailRow(
                    title: "SERVER",
                    value:
                        safeServerLabel(
                            configuration
                                .serverURL
                        )
                )

                detailRow(
                    title:
                        "GEBRUIKERSNAAM",
                    value:
                        configuration
                            .username
                )

                detailRow(
                    title: "WACHTWOORD",
                    value: "••••••••"
                )
            }

        case .m3u(
            let configuration
        ):
            HStack(
                alignment: .top,
                spacing: 40
            ) {
                detailRow(
                    title: "TYPE",
                    value: "M3U"
                )

                detailRow(
                    title: "BRON",
                    value:
                        safeServerLabel(
                            configuration
                                .playlistURL
                        )
                )
            }
        }
    }

    private func detailRow(
        title: String,
        value: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Text(title)
                .font(.caption2)
                .tracking(2)
                .foregroundStyle(
                    .cyan.opacity(0.70)
                )

            Text(value)
                .font(
                    .system(
                        size: 18,
                        weight: .medium
                    )
                )
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyView: some View {
        VStack(
            alignment: .leading,
            spacing: 22
        ) {
            Image(systemName: "tv")
                .font(
                    .system(
                        size: 48,
                        weight: .light
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )

            Text(
                "Geen IPTV-provider ingesteld"
            )
            .font(.title2)

            Text(
                "Voeg een Xtream- of M3U-provider toe."
            )
            .foregroundStyle(
                .secondary
            )

            NavigationLink {
                IPTVSetupView(
                    createsNewProvider: true
                )
            } label: {
                Label(
                    "IPTV TOEVOEGEN",
                    systemImage: "plus"
                )
            }
            .buttonStyle(.bordered)
        }

        Spacer()
    }

    // MARK: - Loading / Error

    @ViewBuilder
    private var loadingView: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            ProgressView()

            Text(
                "IPTV-providers laden…"
            )
            .foregroundStyle(
                .secondary
            )
        }

        Spacer()
    }

    @ViewBuilder
    private func errorView(
        _ message: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            Text(
                "IPTV-providers konden niet worden geladen"
            )
            .font(.title2)

            Text(message)
                .foregroundStyle(
                    .secondary
                )

            Button("OPNIEUW") {
                loadProviders()
            }
        }

        Spacer()
    }

    // MARK: - Load Providers

    private func loadProviders() {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            providers =
                try configurationStore
                    .loadProviders()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    // MARK: - Refresh Provider

    @MainActor
    private func refreshProvider(
        _ provider:
            IPTVStoredProvider
    ) async {
        guard
            !refreshingProviderIDs
                .contains(
                    provider.id
                )
        else {
            return
        }

        refreshingProviderIDs
            .insert(
                provider.id
            )

        providerErrors[
            provider.id
        ] = nil

        refreshMessages[
            provider.id
        ] = nil

        defer {
            refreshingProviderIDs
                .remove(
                    provider.id
                )
        }

        do {
            switch provider.configuration {
            case .xtream(
                let configuration
            ):
                async let live =
                    service
                        .loadXtreamLiveCategories(
                            configuration:
                                configuration
                        )

                async let vod =
                    service
                        .loadXtreamVODCategories(
                            configuration:
                                configuration
                        )

                let result =
                    try await (
                        live,
                        vod
                    )

                refreshMessages[
                    provider.id
                ] =
                    "\(result.0.count) Live TV-categorieën en \(result.1.count) VOD-categorieën geladen."

            case .m3u(
                let configuration
            ):
                let channels =
                    try await service
                        .loadM3UChannels(
                            configuration:
                                configuration
                        )

                refreshMessages[
                    provider.id
                ] =
                    "\(channels.count) zenders geladen."
            }

            NotificationCenter.default.post(
                name:
                    .iptvConfigurationDidChange,
                object: nil
            )
        } catch {
            providerErrors[
                provider.id
            ] =
                error.localizedDescription
        }
    }

    // MARK: - Helpers

    private var providerCountLabel:
        String
    {
        switch providers.count {
        case 0:
            return
                "Geen providers ingesteld"

        case 1:
            return
                "1 provider ingesteld"

        default:
            return
                "\(providers.count) providers ingesteld"
        }
    }

    private func providerTypeLabel(
        _ configuration:
            IPTVStoredConfiguration
    ) -> String {
        switch configuration {
        case .xtream:
            return "XTREAM"

        case .m3u:
            return "M3U"
        }
    }

    private func safeServerLabel(
        _ url: URL
    ) -> String {
        guard
            let components =
                URLComponents(
                    url: url,
                    resolvingAgainstBaseURL:
                        false
                )
        else {
            return "Opgeslagen"
        }

        let scheme =
            components.scheme
            ?? ""

        let host =
            components.host
            ?? "Opgeslagen"

        if
            let port =
                components.port
        {
            return
                "\(scheme)://\(host):\(port)"
        }

        if !scheme.isEmpty {
            return
                "\(scheme)://\(host)"
        }

        return host
    }
}

// MARK: - Provider Management Launcher

private struct IPTVProviderManagementLauncherView:
    View
{
    let providerID: UUID

    @State private var isReady = false
    @State private var errorMessage: String?

    @State private var previousActiveProviderID:
        UUID?

    private let configurationStore =
        IPTVConfigurationStore()

    var body: some View {
        Group {
            if isReady {
                IPTVProviderManagementView()
            } else if
                let errorMessage
            {
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    VStack(
                        spacing: 20
                    ) {
                        Image(
                            systemName:
                                "exclamationmark.triangle"
                        )
                        .font(
                            .system(
                                size: 44
                            )
                        )

                        Text(
                            "Provider kon niet worden geopend"
                        )
                        .font(.title2)

                        Text(
                            errorMessage
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
            } else {
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    ProgressView(
                        "Provider laden…"
                    )
                }
            }
        }
        .task {
            prepareProvider()
        }
        .onDisappear {
            restorePreviousProvider()
        }
    }

    private func prepareProvider() {
        do {
            previousActiveProviderID =
                try configurationStore
                    .activeProviderID()

            try configurationStore
                .setActiveProvider(
                    id: providerID
                )

            isReady = true
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    private func restorePreviousProvider() {
        guard
            let previousActiveProviderID,
            previousActiveProviderID !=
                providerID
        else {
            return
        }

        try? configurationStore
            .setActiveProvider(
                id:
                    previousActiveProviderID
            )
    }
}

#Preview {
    NavigationStack {
        IPTVAccountsView()
    }
}
