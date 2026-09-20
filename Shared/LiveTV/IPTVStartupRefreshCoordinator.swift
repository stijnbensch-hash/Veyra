import Foundation
import SwiftUI

/// Stuurt de "IPTV VOD/EPG automatisch verversen bij opstarten"-animatie
/// aan. Bewust platform-neutraal (geen IPTV-typen in deze klasse zelf),
/// zodat hij op zowel iOS als tvOS werkt — ook op een platform waar de
/// eigenlijke IPTV-service(laag) (tijdelijk) ontbreekt: die kant geeft dan
/// gewoon een lichtgewicht `work`-closure door in plaats van een echte
/// netwerk-ververs.
///
/// Gebruik: elk `App`-struct maakt hier één `@StateObject` van, roept
/// `beginRefresh(work:)` aan in zijn opstart-`.task`, en toont
/// `IPTVStartupRefreshBadge(coordinator:)` als overlay.
@MainActor
final class IPTVStartupRefreshCoordinator: ObservableObject {
    @Published private(set) var isRefreshing = false

    /// Minimale zichtbare duur, zodat de animatie niet als een flits
    /// verschijnt-en-verdwijnt wanneer `work` razendsnel klaar is.
    private let minimumVisibleDuration: Duration = .milliseconds(700)

    private var hasRunOnce = false

    /// Voert `work` uit terwijl de kleine laadanimatie zichtbaar blijft.
    /// Ververst maar één keer per appstart — een terugkeer naar de
    /// voorgrond triggert dit dus niet opnieuw. Ná afloop wordt
    /// `.iptvConfigurationDidChange` gepost, zodat bestaande schermen
    /// (Live TV, IPTV Home-rijen) hun eigen ververs-logica oppikken.
    func beginRefresh(work: @escaping () async -> Void) async {
        guard !hasRunOnce else { return }
        hasRunOnce = true

        withAnimation(.easeInOut(duration: 0.25)) {
            isRefreshing = true
        }

        let start = ContinuousClock.now
        await work()
        let elapsed = ContinuousClock.now - start

        if elapsed < minimumVisibleDuration {
            try? await Task.sleep(for: minimumVisibleDuration - elapsed)
        }

        NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)

        withAnimation(.easeInOut(duration: 0.25)) {
            isRefreshing = false
        }
    }
}
