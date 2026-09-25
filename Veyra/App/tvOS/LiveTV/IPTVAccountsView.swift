import SwiftUI

// MARK: - IPTV overview

@MainActor
struct IPTVAccountsView: View {
    @StateObject private var viewModel = IPTVAccountsViewModel()

    @State private var showAddProvider = false
    @State private var selectedManagementProvider: IPTVStoredProvider?
    @State private var selectedEditProvider: IPTVStoredProvider?

    @FocusState private var addButtonFocused: Bool
    @FocusState private var focusedProviderID: UUID?
    @FocusState private var focusedRefreshID: UUID?
    @FocusState private var focusedEditID: UUID?
    @FocusState private var focusedReorderUpID: UUID?
    @FocusState private var focusedReorderDownID: UUID?

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    header

                    if viewModel.isLoading && viewModel.providers.isEmpty {
                        loadingState
                    } else if let errorMessage = viewModel.errorMessage, viewModel.providers.isEmpty {
                        errorState(errorMessage)
                    } else {
                        addProviderButton
                        existingProvidersSection
                    }
                }
                .frame(maxWidth: 1180, alignment: .leading)
                .padding(.horizontal, 70)
                .padding(.top, 50)
                .padding(.bottom, 70)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .iptvConfigurationDidChange)) { _ in
            viewModel.load()
        }
        .task {
            // Periodiek herchecken zolang dit scherm open staat — zie de
            // gelijkaardige aanpak bij Mediaservers.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                viewModel.refreshStatus()
            }
        }
        .navigationDestination(isPresented: $showAddProvider) {
            IPTVSetupView(createsNewProvider: true)
        }
        .navigationDestination(item: $selectedManagementProvider) { provider in
            IPTVProviderManagementLauncherView(providerID: provider.id)
        }
        .navigationDestination(item: $selectedEditProvider) { provider in
            IPTVSetupView(providerID: provider.id)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 22) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.cyan)
                .frame(width: 4, height: 66)

            VStack(alignment: .leading, spacing: 12) {
                Text("IPTV")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(viewModel.providerCountLabel)
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()
        }
    }

    // MARK: - Add button

    private var addProviderButton: some View {
        let focused = addButtonFocused

        return HStack(spacing: 12) {
            Image(systemName: "plus")

            Text("IPTV TOEVOEGEN")
                .font(.system(size: 22, weight: .semibold))
                .tracking(2)
        }
        .foregroundStyle(focused ? .white : .cyan)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.cyan.opacity(focused ? 0.24 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    focused ? Color.cyan : Color.cyan.opacity(0.25),
                    lineWidth: focused ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused($addButtonFocused)
        .focusEffectDisabled()
        .onTapGesture {
            showAddProvider = true
        }
    }

    // MARK: - Existing providers

    @ViewBuilder
    private var existingProvidersSection: some View {
        Text("GEKOPPELDE PROVIDERS")
            .font(.system(size: 26, weight: .semibold))
            .tracking(3)
            .foregroundStyle(.cyan)

        if viewModel.providers.isEmpty {
            emptyState
        } else {
            VStack(spacing: 12) {
                ForEach(viewModel.providers) { provider in
                    providerRow(provider)
                }
            }
        }
    }

    private func providerRow(_ provider: IPTVStoredProvider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                providerMainControl(provider)
                providerRefreshControl(provider)
                providerEditControl(provider)
                reorderColumn(provider)
            }

            if let message = viewModel.refreshMessages[provider.id] {
                Label(message, systemImage: "checkmark.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(.cyan.opacity(0.85))
                    .padding(.leading, 8)
            }

            if let message = viewModel.providerErrors[provider.id] {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 18))
                    .foregroundStyle(.red)
                    .padding(.leading, 8)
            }
        }
    }

    private func providerMainControl(_ provider: IPTVStoredProvider) -> some View {
        let isFocused = focusedProviderID == provider.id

        return HStack(alignment: .center, spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cyan.opacity(isFocused ? 0.20 : 0.10))

                Image(systemName: providerSymbol(provider.configuration))
                    .font(.system(size: 39, weight: .light))
                    .foregroundStyle(isFocused ? .white : .cyan)
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    statusDot(for: provider.id)

                    Text(provider.displayName)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(providerTypeLabel(provider.configuration))
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.cyan)
                }

                Text(providerSubtitle(provider.configuration))
                    .font(.system(size: 21))
                    .foregroundStyle(.white.opacity(isFocused ? 0.85 : 0.62))
                    .lineLimit(1)
            }

            Spacer()

            Text("Beheren")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(isFocused ? .white : .cyan)

            Image(systemName: "chevron.right")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(isFocused ? .white : .cyan.opacity(0.60))
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    isFocused
                        ? Color.cyan.opacity(0.18)
                        : Color(red: 0.03, green: 0.09, blue: 0.14)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    isFocused ? Color.cyan : Color.cyan.opacity(0.12),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused($focusedProviderID, equals: provider.id)
        .focusEffectDisabled()
        .onTapGesture {
            selectedManagementProvider = provider
        }
    }

    private func providerRefreshControl(_ provider: IPTVStoredProvider) -> some View {
        let isFocused = focusedRefreshID == provider.id
        let isRefreshing = viewModel.refreshingProviderIDs.contains(provider.id)

        return VStack(spacing: 8) {
            if isRefreshing {
                ProgressView()
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 30, weight: .medium))
            }

            Text(isRefreshing ? "LADEN…" : "VERVERSEN")
                .font(.system(size: 15, weight: .semibold))
                .tracking(1)
                .lineLimit(1)
        }
        .foregroundStyle(isFocused ? .white : .cyan.opacity(0.85))
        .frame(width: 118, height: 116)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    isFocused
                        ? Color.cyan.opacity(0.20)
                        : Color(red: 0.03, green: 0.09, blue: 0.14)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isFocused ? Color.cyan : Color.cyan.opacity(0.25),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .opacity(isRefreshing ? 0.65 : 1.0)
        .focusable(true)
        .focused($focusedRefreshID, equals: provider.id)
        .focusEffectDisabled()
        .onTapGesture {
            guard !isRefreshing else { return }
            Task { await viewModel.refreshProvider(provider) }
        }
    }

    private func providerEditControl(_ provider: IPTVStoredProvider) -> some View {
        let isFocused = focusedEditID == provider.id

        return VStack(spacing: 8) {
            Image(systemName: "pencil")
                .font(.system(size: 30, weight: .medium))

            Text("BEWERKEN")
                .font(.system(size: 15, weight: .semibold))
                .tracking(1)
                .lineLimit(1)
        }
        .foregroundStyle(isFocused ? .white : .cyan.opacity(0.85))
        .frame(width: 118, height: 116)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    isFocused
                        ? Color.cyan.opacity(0.20)
                        : Color(red: 0.03, green: 0.09, blue: 0.14)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isFocused ? Color.cyan : Color.cyan.opacity(0.25),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused($focusedEditID, equals: provider.id)
        .focusEffectDisabled()
        .onTapGesture {
            selectedEditProvider = provider
        }
    }

    /// Compacte omhoog/omlaag-knoppen om providers te herschikken, los van de
    /// andere tegels zodat hun grootte ongewijzigd blijft.
    private func reorderColumn(_ provider: IPTVStoredProvider) -> some View {
        VStack(spacing: 8) {
            reorderButton(
                systemImage: "chevron.up",
                isFocused: focusedReorderUpID == provider.id,
                disabled: viewModel.providers.first?.id == provider.id
            ) {
                viewModel.moveProvider(provider, by: -1)
            }
            .focused($focusedReorderUpID, equals: provider.id)

            reorderButton(
                systemImage: "chevron.down",
                isFocused: focusedReorderDownID == provider.id,
                disabled: viewModel.providers.last?.id == provider.id
            ) {
                viewModel.moveProvider(provider, by: 1)
            }
            .focused($focusedReorderDownID, equals: provider.id)
        }
    }

    private func reorderButton(
        systemImage: String,
        isFocused: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(disabled ? .white.opacity(0.2) : (isFocused ? .white : .cyan.opacity(0.85)))
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isFocused && !disabled
                            ? Color.cyan.opacity(0.20)
                            : Color(red: 0.03, green: 0.09, blue: 0.14)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFocused && !disabled ? Color.cyan : Color.cyan.opacity(0.15),
                        lineWidth: isFocused && !disabled ? 2 : 1
                    )
            )
            .contentShape(Rectangle())
            .focusable(!disabled)
            .focusEffectDisabled()
            .onTapGesture {
                guard !disabled else { return }
                action()
            }
    }

    // MARK: - Empty / loading / error

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Geen IPTV-provider ingesteld")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)

            Text("Voeg een Xtream- of M3U-provider toe.")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.03, green: 0.09, blue: 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.cyan.opacity(0.12), lineWidth: 1)
        )
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProgressView()

            Text("IPTV-providers laden…")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("IPTV-providers konden niet worden geladen")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.62))

            Button("OPNIEUW") { viewModel.load() }
                .font(.system(size: 22))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.03, green: 0.09, blue: 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
    }

    /// Klein bolletje: groen (online), rood (offline), grijs zolang de
    /// eerste controle nog loopt — zie `MediaServersSettingsView.statusDot(for:)`.
    private func statusDot(for providerID: UUID) -> some View {
        let color: Color
        switch viewModel.onlineStatus[providerID] {
        case .some(true): color = .green
        case .some(false): color = .red
        case .none: color = .white.opacity(0.3)
        }

        return Circle()
            .fill(color)
            .frame(width: 14, height: 14)
    }

    // MARK: - Helpers

    private func providerSymbol(_ configuration: IPTVStoredConfiguration) -> String {
        switch configuration {
        case .xtream: return "antenna.radiowaves.left.and.right"
        case .m3u: return "list.bullet.rectangle"
        }
    }

    private func providerTypeLabel(_ configuration: IPTVStoredConfiguration) -> String {
        switch configuration {
        case .xtream: return "XTREAM"
        case .m3u: return "M3U"
        }
    }

    private func providerSubtitle(_ configuration: IPTVStoredConfiguration) -> String {
        switch configuration {
        case .xtream(let configuration):
            return "\(configuration.username) · \(safeServerLabel(configuration.serverURL))"
        case .m3u(let configuration):
            return safeServerLabel(configuration.playlistURL)
        }
    }

    private func safeServerLabel(_ url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "Opgeslagen"
        }

        let scheme = components.scheme ?? ""
        let host = components.host ?? "Opgeslagen"

        if let port = components.port {
            return "\(scheme)://\(host):\(port)"
        }

        if !scheme.isEmpty {
            return "\(scheme)://\(host)"
        }

        return host
    }
}

// MARK: - Provider Management Launcher

private struct IPTVProviderManagementLauncherView: View {
    let providerID: UUID

    @State private var isReady = false
    @State private var errorMessage: String?

    @State private var previousActiveProviderID: UUID?

    private let configurationStore = IPTVConfigurationStore()

    var body: some View {
        Group {
            if isReady {
                IPTVProviderManagementView()
            } else if let errorMessage {
                ZStack {
                    VeyraBackground().ignoresSafeArea()

                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 53))

                        Text("Provider kon niet worden geopend")
                            .font(.system(size: 26))

                        Text(errorMessage)
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ZStack {
                    VeyraBackground().ignoresSafeArea()

                    ProgressView("Provider laden…")
                        .font(.system(size: 22))
                }
            }
        }
        .task { prepareProvider() }
        .onDisappear { restorePreviousProvider() }
    }

    private func prepareProvider() {
        do {
            previousActiveProviderID = try configurationStore.activeProviderID()
            try configurationStore.setActiveProvider(id: providerID)
            isReady = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restorePreviousProvider() {
        guard let previousActiveProviderID, previousActiveProviderID != providerID else { return }
        try? configurationStore.setActiveProvider(id: previousActiveProviderID)
    }
}

#Preview {
    NavigationStack {
        IPTVAccountsView()
    }
}
