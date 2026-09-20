import SwiftUI

/// Kleine, niet-blokkerende laadindicator die verschijnt zodra de app bij
/// het opstarten IPTV VOD/EPG-gegevens ververst, en weer verdwijnt zodra
/// dat klaar is. Zie `IPTVStartupRefreshCoordinator`.
struct IPTVStartupRefreshBadge: View {
    @ObservedObject var coordinator: IPTVStartupRefreshCoordinator

    var body: some View {
        VStack {
            HStack {
                Spacer()

                if coordinator.isRefreshing {
                    badge
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var badge: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)

            Text("IPTV verversen…")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }
}
