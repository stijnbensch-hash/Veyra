import SwiftUI

/// iOS-equivalent van tvOS' `WatchProviderRow`: dezelfde databron
/// (`TMDBClient.watchProviders`) en dezelfde regio/selectie-bindings,
/// maar met knoppen die met de vinger te bedienen zijn i.p.v. focus.
struct WatchProviderRowIOS: View {
    let kind: ProviderMediaKind

    @Binding var selection: WatchProvider?
    @Binding var region: String

    @State private var providers: [WatchProvider] = []
    @State private var loading = false
    @State private var error: String?
    @State private var retry = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    regionPicker

                    ForEach(providers) { provider in
                        providerButton(provider)
                    }

                    if loading {
                        ProgressView().frame(width: 60, height: 40)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }

            if let error {
                Text(error).font(.footnote).foregroundStyle(.orange)
            }
        }
        .task(id: "\(region)-\(retry)") { await load() }
    }

    // MARK: - Region

    private var regionPicker: some View {
        Menu {
            regionButton("België", code: "BE")
            regionButton("Nederland", code: "NL")
            regionButton("Verenigde Staten", code: "US")
            regionButton("Verenigd Koninkrijk", code: "GB")
            regionButton("Frankrijk", code: "FR")
            regionButton("Duitsland", code: "DE")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe.europe.africa.fill")
                    .foregroundStyle(VeyraColors.cyan)

                Text(regionName)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(.white.opacity(0.10), in: Capsule())
        }
    }

    private func regionButton(_ name: String, code: String) -> some View {
        Button {
            region = code
        } label: {
            if region == code {
                Label(name, systemImage: "checkmark")
            } else {
                Text(name)
            }
        }
    }

    private var regionName: String {
        switch region {
        case "NL": "Nederland"
        case "US": "Verenigde Staten"
        case "GB": "Verenigd Koninkrijk"
        case "FR": "Frankrijk"
        case "DE": "Duitsland"
        default: "België"
        }
    }

    // MARK: - Provider button

    /// Toont enkel het merklogo van de dienst (geen naam ernaast meer) —
    /// het logo zelf draagt al de merkherkenning en -kleur, dus een aparte
    /// tekstlabel en gevulde achtergrond voegden alleen ruis toe. Enkel een
    /// dun accentrandje maakt nog duidelijk welke dienst geselecteerd is.
    private func providerButton(_ provider: WatchProvider) -> some View {
        let selected = selection?.id == provider.id

        return Button {
            selection = selected ? nil : provider
        } label: {
            WatchProviderLogoIOS(provider: provider)
                .frame(height: 34)
                .padding(.horizontal, 10)
                .frame(height: 40)
                .background(Color.white.opacity(0.06), in: Capsule())
                .overlay(
                    Capsule().strokeBorder(selected ? VeyraColors.cyan : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(provider.name)
        .accessibilityHint(
            selected ? "Selecteer opnieuw om alle titels te tonen" : "Filter op deze streamingdienst"
        )
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - Loading

    @MainActor
    private func load() async {
        loading = true
        error = nil
        providers = []

        guard let token = AppConfiguration.tmdbReadAccessToken else {
            error = "De metadataservice is niet geconfigureerd."
            loading = false
            return
        }

        do {
            let result = try await TMDBClient(readAccessToken: token)
                .watchProviders(kind: kind, region: region)
            try Task.checkCancellation()
            providers = result
        } catch {
            guard !Task.isCancelled else { return }
            self.error = "Streamingdiensten konden niet worden geladen."
        }

        loading = false
    }
}

private struct WatchProviderLogoIOS: View {
    let provider: WatchProvider

    var body: some View {
        AsyncImage(url: provider.logoURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            case .empty:
                ProgressView().scaleEffect(0.7)
            case .failure:
                placeholder
            @unknown default:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: "tv")
            .foregroundStyle(.white.opacity(0.5))
    }
}
