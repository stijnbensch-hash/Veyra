import SwiftUI

struct IPTVAccountsView: View {
    @StateObject private var viewModel = IPTVAccountsViewModel()

    var body: some View {
        ZStack {
            VeyraBackground()
            .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 24
            ) {
                header

                if viewModel.isLoading &&
                    viewModel.providers.isEmpty
                {
                    loadingView
                } else if
                    let errorMessage = viewModel.errorMessage,
                    viewModel.providers.isEmpty
                {
                    errorView(
                        errorMessage
                    )
                } else if viewModel.providers.isEmpty {
                    emptyView
                } else {
                    providerList
                }
            }
            .padding(.horizontal, VeyraSpacing.page)
            .padding(.top, 36)
            .padding(.bottom, 50)
        }
        .onAppear {
            viewModel.load()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for:
                    .iptvConfigurationDidChange
            )
        ) { _ in
            viewModel.load()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("IPTV")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("PROVIDERS")
                .font(.system(size: 18))
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )

            Text(
                viewModel.providerCountLabel
            )
            .font(.system(size: 23))
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
                HStack(spacing: 18) {
                    addProviderButton
                }

                ForEach(viewModel.providers) {
                    provider in

                    HStack(alignment: .top, spacing: 14) {
                        providerCard(
                            provider
                        )

                        reorderColumn(provider)
                    }
                }
            }
            .frame(
                maxWidth: 920,
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
                    .font(.system(size: 22))
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
                            size: 32,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)

                    Text(
                        providerTypeLabel(
                            provider.configuration
                        )
                    )
                    .font(.system(size: 18))
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
                    viewModel.refreshMessages[
                        provider.id
                    ]
            {
                Label(
                    message,
                    systemImage:
                        "checkmark.circle"
                )
                .font(.system(size: 18))
                .foregroundStyle(
                    .cyan.opacity(0.85)
                )
            }

            if
                let message =
                    viewModel.providerErrors[
                        provider.id
                    ]
            {
                Label(
                    message,
                    systemImage:
                        "exclamationmark.triangle"
                )
                .font(.system(size: 18))
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

    // MARK: - Reorder

    /// Compacte omhoog/omlaag-knoppen om providers te herschikken, los van
    /// `providerActions` zodat de kaartgrootte van de bestaande knoppenrij
    /// (VERVERSEN/BEHEREN/BEWERKEN) ongewijzigd blijft.
    private func reorderColumn(_ provider: IPTVStoredProvider) -> some View {
        VStack(spacing: 6) {
            Button {
                viewModel.moveProvider(provider, by: -1)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 30)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(viewModel.providers.first?.id == provider.id)

            Button {
                viewModel.moveProvider(provider, by: 1)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 30)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(viewModel.providers.last?.id == provider.id)
        }
    }

    private func providerActions(
        _ provider:
            IPTVStoredProvider
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                Task {
                    await viewModel.refreshProvider(
                        provider
                    )
                }
            } label: {
                HStack(spacing: 5) {
                    if viewModel.refreshingProviderIDs
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
                        viewModel.refreshingProviderIDs
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
                        size: 20,
                        weight: .semibold
                    )
                )
                .frame(width: 120)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .opacity(
                viewModel.refreshingProviderIDs
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
                            size: 20,
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
                            size: 20,
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
                .font(.system(size: 18))
                .tracking(2)
                .foregroundStyle(
                    .cyan.opacity(0.70)
                )

            Text(value)
                .font(
                    .system(
                        size: 22,
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
                        size: 60,
                        weight: .light
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )

            Text(
                "Geen IPTV-provider ingesteld"
            )
            .font(.system(size: 22))

            Text(
                "Voeg een Xtream- of M3U-provider toe."
            )
            .font(.system(size: 22))
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
                .font(.system(size: 22))
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
            .font(.system(size: 22))
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
            .font(.system(size: 22))

            Text(message)
                .font(.system(size: 22))
                .foregroundStyle(
                    .secondary
                )

            Button("OPNIEUW") {
                viewModel.load()
            }
            .font(.system(size: 22))
        }

        Spacer()
    }

    // MARK: - Load Providers

    // MARK: - Helpers

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
                                size: 53
                            )
                        )

                        Text(
                            "Provider kon niet worden geopend"
                        )
                        .font(.system(size: 26))

                        Text(
                            errorMessage
                        )
                        .font(.system(size: 22))
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
                    .font(.system(size: 22))
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
