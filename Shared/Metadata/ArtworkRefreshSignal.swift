import Foundation
import Combine

/// §66: een artwork-instelling (`ArtworkSettingsStore`) of per-titel override
/// (`VeyraArtworkOverrideStore`) wijzigt af en toe terwijl een scherm met een al opgeloste
/// clearlogo/poster/backdrop open staat (bv. na de picker, of na een VeyraHub-sync vanaf een
/// ander apparaat — zie §63/§64). Dit wist bewust GEEN metadata-cache (dat blijft aan
/// `ArtworkResolver`/`MetadataRepository` zelf, die overrides toch al vers per aanroep lezen) —
/// het is enkel één gedeelde teller zodat een SwiftUI `.task(id:)` die 'm meeneemt opnieuw
/// draait, zonder dat elke aanroeper zijn eigen `NotificationCenter`-observer moet optuigen.
@MainActor
final class ArtworkRefreshSignal: ObservableObject {
    static let shared = ArtworkRefreshSignal()

    @Published private(set) var generation = 0

    private init() {
        NotificationCenter.default.addObserver(
            forName: .artworkSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in self?.generation += 1 }

        NotificationCenter.default.addObserver(
            forName: .artworkOverridesChanged, object: nil, queue: .main
        ) { [weak self] _ in self?.generation += 1 }
    }
}
