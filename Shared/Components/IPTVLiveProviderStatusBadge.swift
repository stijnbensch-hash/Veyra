import SwiftUI

/// Toont de bereikbaarheid van de provider van een live IPTV-kanaal. De
/// controle is dezelfde als in Instellingen > IPTV; hij meet niet of de
/// afzonderlijke videostream al beeld geeft.
struct IPTVLiveProviderStatusBadge: View {
    let source: PlayableSource
    var item: MediaItem? = nil

    @State private var provider: IPTVStoredProvider?
    @State private var isOnline: Bool?

    var body: some View {
        Group {
            if source.kind == .liveTV, let provider {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                    Text(provider.displayName)
                        .lineLimit(1)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.black.opacity(0.55), in: Capsule())
                .accessibilityLabel("\(provider.displayName): \(statusLabel)")
            }
        }
        .task(id: source.id) {
            guard source.kind == .liveTV else { return }
            provider = resolveProvider()
            guard let provider else { return }

            while !Task.isCancelled {
                isOnline = await IPTVAccountsViewModel.ping(provider.configuration)
                do {
                    try await Task.sleep(for: .seconds(45))
                } catch {
                    break
                }
            }
        }
    }

    private var statusColor: Color {
        switch isOnline {
        case .some(true): .green
        case .some(false): .red
        case .none: .white.opacity(0.4)
        }
    }

    private var statusLabel: String {
        switch isOnline {
        case .some(true): "online"
        case .some(false): "offline"
        case .none: "wordt gecontroleerd"
        }
    }

    private func resolveProvider() -> IPTVStoredProvider? {
        let store = IPTVConfigurationStore()
        guard let providers = try? store.loadProviders() else { return nil }

        // Een Xtream-live-URL bevat het providerpad en de accountgegevens.
        // Vergelijk ze uitsluitend lokaal en toon of log de URL nooit.
        let urlMatches = providers.filter { provider in
            guard case .xtream(let account) = provider.configuration else { return false }
            let base = account.serverURL
                .appendingPathComponent("live")
                .appendingPathComponent(account.username)
                .appendingPathComponent(account.password)
            return source.url.scheme == base.scheme
                && source.url.host == base.host
                && source.url.port == base.port
                && source.url.pathComponents.starts(with: base.pathComponents)
        }
        if urlMatches.count == 1 { return urlMatches[0] }

        let name = item?.iptvProviderName ?? source.providerName
        if let name, name != "IPTV" {
            let nameMatches = providers.filter {
                $0.displayName.caseInsensitiveCompare(name) == .orderedSame
            }
            if nameMatches.count == 1 { return nameMatches[0] }
        }

        // De Live TV-gids gebruikt de actieve provider en geeft geen
        // providernaam in zijn afspeelbron mee.
        if source.providerName == nil,
           let activeID = try? store.activeProviderID(),
           let active = providers.first(where: { $0.id == activeID }) {
            return active
        }

        return providers.count == 1 ? providers[0] : nil
    }
}
