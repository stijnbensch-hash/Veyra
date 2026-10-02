import SwiftUI

/// Artwork-engine-spec §74: "alleen als dit betrouwbaar vastgesteld kan worden" -- geen gok,
/// enkel een echte (korte) manifest-aanvraag naar de addon zelf. Hergebruikt
/// `StremioManifestFetcher` (al gebruikt bij het toevoegen van een addon bij Addons) i.p.v. een
/// eigen rechtstreekse netwerkaanvraag op te zetten.
enum AddonConnectivityStatus: Equatable {
    case checking
    case connected
    case unavailable
}

enum AddonConnectivityChecker {
    static func check(_ addon: AddonManifest) async -> AddonConnectivityStatus {
        do {
            _ = try await StremioManifestFetcher.fetch(from: addon.baseURL)
            return .connected
        } catch {
            return .unavailable
        }
    }
}

/// Compacte status-rij (§74): "AIOMetadata / Verbonden" of "AIOMetadata / Addon niet
/// beschikbaar" -- nooit zichtbaar in de normale UI (§72), enkel in Instellingen/Diagnostics.
struct AddonConnectivityRow: View {
    let addon: AddonManifest
    let status: AddonConnectivityStatus?

    var body: some View {
        HStack {
            Text(addon.name)
            Spacer()
            switch status {
            case .none, .some(.checking):
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Controleren…").foregroundStyle(.secondary)
                }
            case .some(.connected):
                Label("Verbonden", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(VeyraColors.cyan)
            case .some(.unavailable):
                Label("Addon niet beschikbaar", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .font(.subheadline)
    }
}
