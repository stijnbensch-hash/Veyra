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
    @Environment(\.veyraCatalogHeroLayout) private var catalogLayout
    @ViewBuilder let actions: () -> Actions
    var body: some View {
        VStack(alignment: .leading, spacing: catalogLayout == nil ? 16 : 12) {
            if !eyebrow.isEmpty {
                HStack(spacing: 10) {
                    Capsule().fill(VeyraColors.red).frame(width: 28, height: 5)
                    Text(eyebrow.uppercased()).font(.system(size: 18, weight: .medium)).tracking(4).foregroundStyle(VeyraColors.ice)
                }
            }
            Group {
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
            }
            .frame(height: catalogLayout?.titleHeight, alignment: .leading)
            if !metadata.isEmpty || catalogLayout != nil {
                HStack(spacing: 12) {
                    ForEach(metadata, id: \.self) { value in
                        Text(value).font(.system(size: 19, weight: .medium)).padding(.horizontal, 13).padding(.vertical, 7)
                            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.10)))
                    }
                }
                .frame(height: catalogLayout == nil ? nil : 40, alignment: .leading)
            }
            if let item {
                ZStack(alignment: .leading) {
                    // Een lege ratings-view is EmptyView; alleen .frame reserveert
                    // daarvoor geen rij in de VStack. De transparante rij doet dat wel.
                    if let catalogLayout {
                        Color.clear.frame(height: catalogLayout.ratingsHeight)
                    }
                    MetadataRatingsView(ratings: heroRatings(for: item),
                                        maxItems: heroRatingLimit, compact: true)
                }
                .frame(height: catalogLayout?.ratingsHeight, alignment: .leading)
            }
            if catalogLayout != nil || !(overview ?? "").isEmpty {
                Text(overview ?? "").font(VeyraTypography.body).foregroundStyle(.white.opacity(0.78))
                    .lineSpacing(4).lineLimit(3)
                    .frame(height: catalogLayout?.overviewHeight, alignment: .topLeading)
            }
            HStack(spacing: 22, content: actions).padding(.top, 8)
                .frame(height: catalogLayout?.actionsHeight, alignment: .leading)
        }
        .frame(maxWidth: 860, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, catalogLayout == nil ? 28 : 20)
        #if os(iOS)
        // Op de Films/Series-hero (catalogLayout != nil) zat "Meer
        // informatie" te dicht tegen de onderrand -- extra lucht eronder
        // duwt het hele blok (bij het centreren in VeyraCatalogHero) iets
        // omhoog. Alleen iOS: tvOS/macOS stonden al goed.
        .padding(.bottom, catalogLayout != nil ? 14 : 0)
        #endif
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

/// Een stabiele hero-band voor Films/Series. De maten hangen niet af van de titel
/// of van laat geladen logo's/scores; alleen de artwork wisselt binnen deze band.
struct VeyraCatalogHeroLayout: Equatable {
    let plusText: Bool
    private var extraTitleHeight: CGFloat {
        guard plusText else { return 0 }
        #if os(tvOS)
        return 148
        #else
        return 88
        #endif
    }
    var titleHeight: CGFloat {
        #if os(tvOS)
        142 + extraTitleHeight
        #else
        84 + extraTitleHeight
        #endif
    }
    var height: CGFloat {
        #if os(tvOS)
        420 + extraTitleHeight
        #else
        340 + extraTitleHeight
        #endif
    }
    var ratingsHeight: CGFloat {
        #if os(tvOS)
        36
        #else
        27
        #endif
    }
    var actionsHeight: CGFloat {
        #if os(tvOS)
        76
        #else
        48
        #endif
    }
    var overviewHeight: CGFloat {
        #if os(tvOS)
        92
        #else
        66
        #endif
    }
    var horizontalPadding: CGFloat {
        #if os(tvOS)
        80
        #else
        16
        #endif
    }
}

private struct VeyraCatalogHeroLayoutKey: EnvironmentKey {
    static let defaultValue: VeyraCatalogHeroLayout? = nil
}
extension EnvironmentValues {
    var veyraCatalogHeroLayout: VeyraCatalogHeroLayout? {
        get { self[VeyraCatalogHeroLayoutKey.self] }
        set { self[VeyraCatalogHeroLayoutKey.self] = newValue }
    }
}

struct VeyraCatalogHero<Content: View>: View {
    let url: URL?
    var topInset: CGFloat = 0
    @ViewBuilder let content: () -> Content
    @ObservedObject private var artworkRefresh = ArtworkRefreshSignal.shared

    var body: some View {
        let layout = VeyraCatalogHeroLayout(plusText: ArtworkSettingsStore().load().titleDisplay == .clearLogoPlusText)
        content()
            .environment(\.veyraCatalogHeroLayout, layout)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.top, topInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: layout.height + topInset, alignment: .center)
            .background { VeyraHeroArtworkBackground(url: url) }
    }
}
