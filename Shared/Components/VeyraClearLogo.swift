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

    var body: some View {
        Group {
            if let logoURL {
                AsyncImage(url: logoURL) { phase in
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
            } else {
                fallbackText
            }
        }
        .task(id: item.tmdbID) {
            logoURL = await ClearLogoService.logoURL(for: item)
        }
    }

    private var fallbackText: some View {
        Text(fallbackTitle)
            .font(font)
            .foregroundStyle(.white)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
}
