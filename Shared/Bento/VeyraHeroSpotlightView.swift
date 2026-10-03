// VeyraHeroSpotlightView.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// De nieuwe Home-hero bovenaan: een automatisch wisselende carrousel van
// trending/Trakt-titels, naar het voorbeeld van de Strand-app. Twee stijlen
// (zie VeyraHeroSpotlightSettings.swift):
//   .fullscreen -> achtergrond van rand tot rand
//   .card       -> afgeronde carrousel met zichtbare buren
// Wisselt automatisch (elke 7s); op iOS/iPadOS/macOS ook handmatig te
// swipen. Geen TabView (die heeft op tvOS geen bruikbare paginastijl voor
// dit soort volledig-beeld-carrousel) -- gewoon één huidige slide met een
// crossfade, zodat het gedrag op alle platformen identiek en voorspelbaar is.

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct VeyraHeroSpotlightView: View {
    let items: [HeroSpotlightItem]
    let style: HeroSpotlightStyle
    var height: CGFloat = 520

    /// Optie voor schermen die de achtergrond zelf tekenen.
    /// Home houdt de afbeelding op iOS en macOS binnen de scrollende hero.
    var externalBackdrop = false
    /// Meldt de huidige carrousel-index naar buiten, zodat een aanroeper met
    /// `externalBackdrop = true` weet welke afbeelding hij zelf moet tonen.
    var onIndexChange: ((Int) -> Void)?
    /// "Context Ribbon": optionele, per-item contextuele badge boven de titel
    /// (bv. "Verder kijken · S2E4 · nog 23 min" wanneer dit item ook in
    /// Verder kijken staat). Een closure i.p.v. een losse waarde, zodat de
    /// juiste info altijd meeschuift met de automatisch wisselende carrousel
    /// zonder dat de aanroeper de interne `index` hoeft te kennen. `nil`
    /// (default) laat de ribbon gewoon weg.
    var contextInfo: ((HeroSpotlightItem) -> VeyraPulseInfo?)? = nil

    @Environment(\.openMediaDetail) private var openMediaDetail

    @State private var index = 0
    @State private var advanceTask: Task<Void, Never>?
    @State private var ratingsByID: [String: MetadataRatings] = [:]
    #if !os(tvOS)
    @State private var dragOffset: CGFloat = 0
    #endif

    private var current: HeroSpotlightItem? {
        items.indices.contains(index) ? items[index] : nil
    }

    /// Hoeveel de achtergrond voorbij de hero zelf doorloopt voordat hij
    /// helemaal opgaat in de pagina-achtergrond -- zorgt dat de rij
    /// eronder (bv. "Verder kijken") niet met een harde rand botst, net als
    /// bij Strand/Films.
    private let ambientBleed: CGFloat = 220

    private var slideHeight: CGFloat {
        #if os(tvOS)
        // De achtergrond loopt ook door in de vervaging onder de hero.
        // Laat de inhoud tot aan die onderrand zakken zonder de rijen eronder
        // te verplaatsen: die extra hoogte telde al mee in de ZStack.
        return style == .fullscreen && !externalBackdrop ? height + ambientBleed : height
        #else
        return height
        #endif
    }

    var body: some View {
        Group {
            if let current {
                ZStack(alignment: .top) {
                    // iOS en macOS tekenen de achtergrond in de scrollende hero.
                    // Op tvOS zit hij in de knop zelf.
                    #if !os(tvOS)
                    if style == .fullscreen, !externalBackdrop {
                        scrollingBackdrop(current)
                    }
                    #endif
                    VStack(spacing: 14) {
                        slide(current)
                            .padding(.horizontal, style == .card ? 28 : 0)
                            .frame(height: slideHeight)
                            #if os(tvOS)
                            .ignoresSafeArea(edges: style == .fullscreen ? .top : [])
                            #endif
                            #if !os(tvOS)
                            .offset(x: dragOffset)
                            .gesture(swipeGesture)
                            #endif

                        if items.count > 1 { dots }
                    }
                }
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .onAppear {
            restartAutoAdvance()
            onIndexChange?(index)
        }
        .onDisappear { advanceTask?.cancel() }
        .onChange(of: items.map(\.id)) { _, _ in
            index = 0
            restartAutoAdvance()
        }
        .onChange(of: index) { _, newValue in
            onIndexChange?(newValue)
        }
        .task(id: current?.id) {
            guard let item = current, let tmdbID = item.mediaItem.tmdbID,
                  ratingsByID[item.id] == nil else { return }
            let loaded: MetadataRatings
            if item.isMovie {
                loaded = await MetadataRatingsService.movieRatings(
                    tmdbID: tmdbID, imdbID: item.mediaItem.imdbID,
                    title: item.mediaItem.title, knownTMDBRating: item.rating
                )
            } else {
                loaded = await MetadataRatingsService.seriesRatings(
                    tmdbID: tmdbID, imdbID: item.mediaItem.imdbID,
                    title: item.mediaItem.title, knownTMDBRating: item.rating
                )
            }
            guard !Task.isCancelled else { return }
            ratingsByID[item.id] = loaded
        }
    }

    #if !os(tvOS)
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in dragOffset = value.translation.width }
            .onEnded { value in
                let threshold: CGFloat = 60
                withAnimation(.easeOut(duration: 0.3)) {
                    if value.translation.width < -threshold {
                        goTo(index + 1)
                    } else if value.translation.width > threshold {
                        goTo(index - 1)
                    }
                    dragOffset = 0
                }
            }
    }
    #endif

    private func goTo(_ newIndex: Int) {
        guard !items.isEmpty else { return }
        index = ((newIndex % items.count) + items.count) % items.count
        restartAutoAdvance()
    }

    private func restartAutoAdvance() {
        advanceTask?.cancel()
        guard items.count > 1 else { return }
        advanceTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.6)) {
                    index = (index + 1) % items.count
                }
            }
        }
    }

    // MARK: Doorlopende achtergrond (alleen schermvullend)

    /// Eén afbeelding met een transparante onderrand naar de echte pagina-achtergrond.
    /// Ook de leesbaarheidslaag vervaagt mee, zodat er geen zwarte balk overblijft.
    private func backdrop(_ item: HeroSpotlightItem) -> some View {
        VeyraHeroAmbientBackdrop(url: item.backdropURL, id: item.id, height: height, bleed: ambientBleed)
    }

    #if !os(tvOS)
    /// De hero is zelf het scrollende beeldvlak. Gebruik ook op iPhone de
    /// backdrop: posters hebben vaak de filmtitel al in de afbeelding staan,
    /// terwijl het losse clearlogo onderaan de hero die titel opnieuw toont.
    private func scrollingBackdrop(_ item: HeroSpotlightItem) -> some View {
        backdrop(item)
            // Behoud de bestaande layoutmaat; alleen het beeld vervaagt verder
            // onder de paginastippen en de eerste rij, zonder inhoud te verschuiven.
            .frame(height: height + 20, alignment: .top)
    }
    #endif

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.white : Color.white.opacity(0.32))
                    .frame(width: i == index ? 16 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: index)
    }

    // MARK: Eén slide

    @ViewBuilder
    private func slide(_ item: HeroSpotlightItem) -> some View {
        #if os(tvOS)
        Button {
            openMediaDetail(item.mediaItem)
        } label: {
            slideContent(item)
        }
        .buttonStyle(HeroSpotlightButtonStyle())
        #else
        NavigationLink {
            ShelfItemDestination(item: item.mediaItem)
        } label: {
            slideContent(item)
        }
        .buttonStyle(.plain)
        #endif
    }

    private func slideContent(_ item: HeroSpotlightItem) -> some View {
        ZStack(alignment: .bottomLeading) {
                #if os(tvOS)
                // Eén beeldlaag binnen de selecteerbare knop. Zo kan een
                // aparte achtergrond niet onder de focuslaag uitsteken.
                if style == .fullscreen, !externalBackdrop {
                    backdrop(item)
                }
                #endif
                // Kaartstijl: eigen afbeelding. In de schermvullende tvOS-
                // stijl staat de doorlopende achtergrond hierboven al in
                // dezelfde ZStack; iOS/macOS tekenen die buiten de slide.
                if style == .card {
                    GeometryReader { geo in
                        VeyraAsyncImage(url: item.backdropURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Color.black
                            }
                        }
                        .id(item.id)
                        .transition(.opacity)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    }
                }

                if style == .card || externalBackdrop {
                    LinearGradient(colors: [.black.opacity(0.9), .black.opacity(0.25), .clear],
                                   startPoint: .bottom, endPoint: .center)
                }

                content(item)
                    .id(item.id)
                    .transition(.opacity)
                    .padding(.horizontal, style == .fullscreen ? 24 : 20)
                    .padding(.bottom, 22)
            }
            // Ook zonder een beeldvullende overlay moet de inhoud onderaan
            // de vaste hero-band staan, niet midden in de resterende ruimte.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .clipShape(RoundedRectangle(cornerRadius: style == .card ? 20 : 0, style: .continuous))
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.4), value: item.id)
    }

    private func content(_ item: HeroSpotlightItem) -> some View {
        VStack(alignment: centeredOnIOS ? .center : .leading, spacing: contentSpacing) {
            if let contextInfo, let info = contextInfo(item) {
                VeyraPulseBadge(info: info, compact: pulseBadgeCompact)
            }
            if let logoURL = item.logoURL {
                VeyraAsyncImage(url: logoURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    }
                }
                .frame(maxWidth: logoMaxWidth, maxHeight: logoMaxHeight,
                       alignment: centeredOnIOS ? .center : .leading)
            } else {
                Text(item.title)
                    .font(.system(size: titleFontSize, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(centeredOnIOS ? .center : .leading)
            }

            MetadataRatingsView(ratings: heroRatings(for: item),
                                maxItems: heroRatingLimit, compact: true)

            Text(metaLine(item))
                .font(.system(size: metaFontSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let overview = item.overview, !overview.isEmpty {
                Text(overview)
                    .font(.system(size: overviewFontSize))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(overviewLineLimit)
                    .multilineTextAlignment(centeredOnIOS ? .center : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: centeredOnIOS ? .center : .leading)
    }

    private var centeredOnIOS: Bool {
        #if os(iOS)
        style == .fullscreen
        #else
        false
        #endif
    }

    // 10-voet-maten op tvOS: merkbaar groter zodat clearlogo en infotekst vanaf de bank
    // leesbaar zijn -- op iOS/iPadOS/macOS blijven de compactere maten van dichtbij bekeken.
    #if os(tvOS)
    private let contentSpacing: CGFloat = 18
    private let logoMaxWidth: CGFloat = 560
    private let logoMaxHeight: CGFloat = 130
    private let titleFontSize: CGFloat = 56
    private let metaFontSize: CGFloat = 26
    private let overviewFontSize: CGFloat = 28
    private let overviewLineLimit = 3
    #else
    private let contentSpacing: CGFloat = 10
    private let logoMaxWidth: CGFloat = 280
    private let logoMaxHeight: CGFloat = 72
    private let titleFontSize: CGFloat = 30
    private let metaFontSize: CGFloat = 14
    private let overviewFontSize: CGFloat = 14
    private let overviewLineLimit = 2
    #endif

    // Zelfde 10-voet- vs. van-dichtbij-onderscheid als `contentSpacing`/
    // `titleFontSize` hierboven: groot en leesbaar op tvOS, compacter op
    // iOS/iPadOS/macOS.
    private var pulseBadgeCompact: Bool {
        #if os(tvOS)
        false
        #else
        true
        #endif
    }

    private func metaLine(_ item: HeroSpotlightItem) -> String {
        var parts: [String] = []
        if let year = item.year { parts.append(year) }
        if let genre = item.genre { parts.append(genre) }
        parts.append(item.isMovie ? "Film" : "Serie")
        return parts.joined(separator: " · ")
    }

    private func heroRatings(for item: HeroSpotlightItem) -> MetadataRatings {
        var ratings = ratingsByID[item.id] ?? MetadataRatings()
        // De catalogusscore is meteen beschikbaar; aanvullende bronnen laden
        // pas wanneer deze slide zichtbaar wordt.
        if ratings.tmdb == nil, let value = item.rating, value > 0 {
            ratings.tmdb = value
        }
        return ratings
    }

    private var heroRatingLimit: Int {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone ? 3 : 5
        #else
        return 5
        #endif
    }
}

#if os(tvOS)
private struct HeroSpotlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LabelView(configuration: configuration)
            .focusEffectDisabled()
    }

    private struct LabelView: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .overlay(alignment: .bottomLeading) {
                    if isFocused {
                        Capsule()
                            .fill(VeyraColors.cyan)
                            .frame(width: 72, height: 5)
                            .padding(.leading, 24)
                            .padding(.bottom, 6)
                    }
                }
                .opacity(configuration.isPressed ? 0.92 : 1)
        }
    }
}
#endif


/// Eén doorlopende achtergrond die voorbij de hero-hoogte transparant wordt
/// boven de bestaande schermachtergrond -- gedeeld door `VeyraHeroSpotlightView`
/// zelf (wanneer die de achtergrond intern tekent) én door schermen die hem
/// BUITEN hun ScrollView om moeten tekenen (zie `externalBackdrop` hierboven).
/// Eén enkele afbeelding i.p.v. een losse vervaagde kopie, anders knippen
/// twee onafhankelijke `AsyncImage`-lagen van dezelfde URL niet gegarandeerd
/// identiek uit -- dat gaf eerder een zichtbare naad.
struct VeyraHeroAmbientBackdrop: View {
    let url: URL?
    let id: AnyHashable
    var height: CGFloat
    var bleed: CGFloat = 220

    var body: some View {
        GeometryReader { geo in
            VeyraAsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Color.clear
                }
            }
            .id(id)
            .transition(.opacity)
            .frame(width: geo.size.width, height: height + bleed)
            .clipped()
            .veyraHeroBackdropBlend()
        }
        .frame(height: height + bleed)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.5), value: id)
    }
}
