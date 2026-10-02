// BecauseYouWatchedOverlay.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// "Omdat je X keek" -- aanbevelingskaart die in de speler verschijnt zodra
// een film, of de laatste aflevering van een serie, bijna is afgelopen én
// er geen "Volgende aflevering" is om naar door te schakelen. Toont één
// verwante titel (`SimilarTitlesService`) met kijklijst-/favoriet-acties.
// De acties zelf blijven platformeigen (`WatchlistToggleButton`/
// `FavoriteToggleButton` bestaan apart voor tvOS/iOS/macOS), vandaar de
// generieke `actions`-ViewBuilder i.p.v. ze hier rechtstreeks aan te roepen.
import SwiftUI

struct BecauseYouWatchedOverlay<Actions: View>: View {
    let sourceTitle: String
    let recommended: MediaItem
    let onDismiss: () -> Void
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VeyraAsyncImage(url: recommended.posterURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        VeyraColors.surface
                        Image(systemName: recommended.type == .movie ? "film" : "tv")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .frame(width: posterWidth, height: posterWidth * 3 / 2)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("OMDAT JE \(sourceTitle.uppercased()) KEEK")
                    .font(.system(size: labelSize, weight: .bold))
                    .foregroundStyle(VeyraColors.cyan)
                    .lineLimit(1)

                Text(recommended.title)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 10) { actions() }
                    .padding(.top, 2)
            }
            .frame(maxWidth: textMaxWidth, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var posterWidth: CGFloat {
        #if os(tvOS)
        92
        #else
        70
        #endif
    }
    private var textMaxWidth: CGFloat {
        #if os(tvOS)
        260
        #else
        190
        #endif
    }
    private var labelSize: CGFloat {
        #if os(tvOS)
        14
        #else
        11
        #endif
    }
    private var titleSize: CGFloat {
        #if os(tvOS)
        21
        #else
        16
        #endif
    }
}
