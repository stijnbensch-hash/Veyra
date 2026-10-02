import SwiftUI

/// Titel-weergave op een detailscherm: toont TMDB's clearlogo (transparante
/// titel-afbeelding) wanneer beschikbaar, anders gewoon de titel als tekst
/// in de opgegeven stijl -- zodat een titel zonder logo er precies zo
/// uitziet als voorheen.
struct VeyraClearLogo: View {
    let item: MediaItem
    let fallbackTitle: String
    var maxWidth: CGFloat = 520
    var maxHeight: CGFloat = 110
    var font: Font
    var alignment: HorizontalAlignment = .leading

    @State private var logoURL: URL?
    // Fase 3 stap 4 (artwork-engine-spec §40): "ClearLogo + tekst" toont, anders dan de overige
    // modi, de titeltekst ALTIJD mee onder het logo -- alleen relevant hier (Detail/Hero/Player-
    // contextbalk/Collection-logokeuze); de compacte Bento-/"Nieuw van hier"-kaarten (`VeyraTitleLogo`)
    // hebben geen ruimte voor logo + tekst samen en blijven bij logo-of-tekst.
    @State private var showTextAlongsideLogo = false
    // §66: herlaadt wanneer een artwork-instelling of per-titel override wijzigt terwijl dit
    // scherm al open staat (bv. na de picker, of een VeyraHub-sync vanaf een ander apparaat).
    @ObservedObject private var artworkRefresh = ArtworkRefreshSignal.shared

    var body: some View {
        Group {
            if let logoURL {
                VStack(alignment: alignment, spacing: 6) {
                    VeyraAsyncImage(url: logoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
                        default:
                            fallbackText
                        }
                    }
                    if showTextAlongsideLogo {
                        fallbackText
                    }
                }
            } else {
                fallbackText
            }
        }
        .task(id: "\(item.tmdbID ?? -1):\(artworkRefresh.generation)") {
            // Fase 3 (artwork-engine-spec §29/§30): via de centrale `ArtworkResolver`
            // i.p.v. hier altijd rechtstreeks TMDB te bevragen — respecteert zo ook een
            // gekozen AIOMetadata-addon, met dezelfde TMDB-terugval. "Altijd tekst" (§40)
            // levert hier al `nil` op via de resolver zelf, dus geen extra check nodig.
            showTextAlongsideLogo = ArtworkSettingsStore().load().titleDisplay == .clearLogoPlusText
            logoURL = await ArtworkResolver.shared.clearLogoURL(for: item)
        }
    }

    private var fallbackText: some View {
        // Zonder eigen `maxWidth` hier (anders dan de AsyncImage-tak hierboven) kon een lange
        // titel zonder clearlogo (bv. net-aangekondigde titels die TMDB nog geen logo-asset voor
        // heeft) breder willen zijn dan het scherm. Een ZStack/HStack dwingt zijn kinderen niet
        // tot een breedte -- dat liet de tekst dan ongeclipt over de randen heen lopen, en duwde
        // de hele omliggende layout (Instant Peek, hero) mee uit zijn voegen.
        Text(fallbackTitle)
            .font(font)
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: maxWidth, alignment: Alignment(horizontal: alignment, vertical: .center))
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
}
