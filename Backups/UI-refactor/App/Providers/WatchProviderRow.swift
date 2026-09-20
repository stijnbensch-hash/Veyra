import SwiftUI

struct WatchProviderRow: View {
    let kind: ProviderMediaKind
    @Binding var selection: WatchProvider?
    @Binding var region: String
    @State private var providers: [WatchProvider] = []
    @State private var loading = false
    @State private var error: String?
    @State private var retry = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 24) {
                Text("STREAMINGDIENSTEN").font(.system(size: 18, weight: .semibold)).tracking(2).foregroundStyle(.cyan)
                Spacer()
                Picker("Aanbod", selection: $region) {
                    Text("België").tag("BE")
                    Text("Nederland").tag("NL")
                    Text("Verenigde Staten").tag("US")
                    Text("Verenigd Koninkrijk").tag("GB")
                    Text("Frankrijk").tag("FR")
                    Text("Duitsland").tag("DE")
                }.frame(width: 340)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(providers) { provider in providerButton(provider) }
                    if loading { ProgressView().frame(width: 80) }
                }.padding(.horizontal, 12).padding(.vertical, 14)
            }.scrollClipDisabled()
            if let error {
                HStack {
                    Text(error).font(.system(size: 18)).foregroundStyle(.orange)
                    Button("Opnieuw") { retry += 1 }.font(.system(size: 18))
                }
            }
            Text("Beschikbaarheid: JustWatch via TMDB · Abonnement, huur of koop kan nodig zijn.")
                .font(.system(size: 16)).foregroundStyle(.secondary)
        }
        .task(id: "\(region)-\(retry)") { await load() }
    }

    private func providerButton(_ provider: WatchProvider) -> some View {
        let selected = selection?.id == provider.id
        return Button { selection = selected ? nil : provider } label: {
            AsyncImage(url: provider.logoURL) { phase in
                if let image = phase.image { image.resizable().scaledToFit() }
                else { Image(systemName: "play.tv").font(.system(size: 24)).foregroundStyle(.cyan) }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(12)
            .background(selected ? Color.cyan.opacity(0.22) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? .cyan : .white.opacity(0.12), lineWidth: selected ? 3 : 1))
        }
        .buttonStyle(.card)
        .accessibilityLabel(provider.name)
        .accessibilityHint(selected ? "Selecteer opnieuw om alle titels te tonen" : "Filter op deze streamingdienst")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @MainActor private func load() async {
        loading = true
        error = nil
        providers = []
        guard let token = AppConfiguration.tmdbReadAccessToken else {
            error = "De metadataservice is niet geconfigureerd."
            loading = false
            return
        }
        do {
            let result = try await TMDBClient(readAccessToken: token).watchProviders(kind: kind, region: region)
            try Task.checkCancellation()
            providers = result
        } catch {
            guard !Task.isCancelled else { return }
            self.error = "Streamingdiensten konden niet worden geladen."
        }
        loading = false
    }
}
