import SwiftUI
#if os(iOS)
import UIKit
#endif

struct VeyraActionLabel: View {
    let title: String
    let symbol: String
    var compact = false
    var body: some View {
        Label(title, systemImage: symbol).font(.system(size: fontSize, weight: .semibold))
            .lineLimit(compact ? 1 : nil)
            .foregroundStyle(.white).padding(.horizontal, horizontalPadding).frame(height: height)
            // Zonder dit knijpt SwiftUI de tekst samen (en laat 'm afbreken)
            // zodra meerdere van deze knoppen niet allemaal naast elkaar
            // passen -- de knop mag daarom breder worden dan zijn buren.
            .fixedSize(horizontal: true, vertical: false)
    }

    // Op tvOS blijft dit knopformaat groot genoeg om vanaf de bank te lezen;
    // op iPhone is diezelfde maat een veel te grote pil naast een kleinere titel.
    private var fontSize: CGFloat {
        #if os(tvOS)
        compact ? 20 : 24
        #else
        15
        #endif
    }

    private var horizontalPadding: CGFloat {
        #if os(tvOS)
        compact ? 18 : 26
        #else
        18
        #endif
    }

    private var height: CGFloat {
        #if os(tvOS)
        compact ? 56 : 68
        #else
        40
        #endif
    }
}

struct VeyraHero<Actions: View>: View {
    let title: String
    var eyebrow: String = ""
    var overview: String?
    var metadata: [String] = []
    var item: MediaItem? = nil
    @State private var ratings = MetadataRatings()
    @ViewBuilder let actions: () -> Actions
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !eyebrow.isEmpty {
                HStack(spacing: 10) {
                    Capsule().fill(VeyraColors.red).frame(width: 28, height: 5)
                    Text(eyebrow.uppercased()).font(.system(size: 18, weight: .medium)).tracking(4).foregroundStyle(VeyraColors.ice)
                }
            }
            if let item {
                VeyraClearLogo(
                    item: item,
                    fallbackTitle: title,
                    maxWidth: logoWidth,
                    maxHeight: logoHeight,
                    font: .system(size: titleFontSize, weight: .bold, design: .rounded)
                )
                .shadow(color: .black.opacity(0.6), radius: 18, y: 8)
            } else {
                Text(title)
                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.6), radius: 18, y: 8)
            }
            if !metadata.isEmpty {
                HStack(spacing: 12) {
                    ForEach(metadata, id: \.self) { value in
                        Text(value).font(.system(size: 19, weight: .medium)).padding(.horizontal, 13).padding(.vertical, 7)
                            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.10)))
                    }
                }
            }
            if let item {
                MetadataRatingsView(ratings: heroRatings(for: item),
                                    maxItems: heroRatingLimit, compact: true)
            }
            if let overview, !overview.isEmpty {
                Text(overview).font(VeyraTypography.body).foregroundStyle(.white.opacity(0.78))
                    .lineSpacing(4).lineLimit(3)
            }
            HStack(spacing: 22, content: actions).padding(.top, 8)
        }
        .frame(maxWidth: 860, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 28)
        #if os(tvOS)
        .focusSection()
        #endif
        .task(id: item.map { "\($0.type.rawValue)|\($0.tmdbID ?? 0)" }) {
            ratings = MetadataRatings()
            guard let item, let tmdbID = item.tmdbID else { return }
            // tvOS wisselt deze hero ook bij focusbewegingen; wacht tot de
            // keuze even stilstaat voordat externe ratingbronnen laden.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let loaded: MetadataRatings
            switch item.type {
            case .movie:
                loaded = await MetadataRatingsService.movieRatings(
                    tmdbID: tmdbID, imdbID: item.imdbID, title: item.title, knownTMDBRating: item.rating
                )
            case .series:
                loaded = await MetadataRatingsService.seriesRatings(
                    tmdbID: tmdbID, imdbID: item.imdbID, title: item.title, knownTMDBRating: item.rating
                )
            case .liveTV, .iptvSeries:
                return
            }
            guard !Task.isCancelled else { return }
            ratings = loaded
        }
    }

    private func heroRatings(for item: MediaItem) -> MetadataRatings {
        var result = ratings
        if result.tmdb == nil, let value = item.rating, value > 0 {
            result.tmdb = value
        }
        return result
    }

    private var heroRatingLimit: Int {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone ? 3 : 5
        #else
        return 5
        #endif
    }

    // 58pt is prima op een tv-scherm, maar op iPhone knipt dat titels als
    // "Spider-Man: Brand New Day" na twee woorden af — daar dus kleiner.
    private var titleFontSize: CGFloat {
        #if os(tvOS)
        58
        #else
        34
        #endif
    }

    private var logoWidth: CGFloat {
        #if os(tvOS)
        620
        #else
        320
        #endif
    }

    private var logoHeight: CGFloat {
        #if os(tvOS)
        140
        #else
        80
        #endif
    }
}
