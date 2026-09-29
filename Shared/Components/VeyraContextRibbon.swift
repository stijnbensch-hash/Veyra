// VeyraContextRibbon.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// "Veyra Now": een tijdslijn-rail i.p.v. één roulerend blokje. Verleden
// (gedimd), "nu" (uitgelicht, met puls) en toekomst staan op één
// horizontale, scrollbare rij, zodat in één oogopslag duidelijk is wat net
// speelde, wat nu relevant is en wat er zo aankomt -- een uniek Veyra-beeld
// i.p.v. een generieke combinatie van "Verder kijken" + "Binnenkort" (die
// rijen blijven daarnaast gewoon bestaan; deze rail is er een aanvulling op).
// Elk soort moment krijgt zijn eigen kaartindeling (zie `contentKind`
// hieronder) i.p.v. één generiek sjabloon, en elke kaart past zich aan zijn
// eigen tekst aan i.p.v. een vaste breedte te forceren -- dat geldt voor elk
// toekomstig type dat hier nog bijkomt.
// Bewust GEEN eigen databron: elk scherm bouwt de items uit dezelfde
// ContinueItem/UpcomingItem/BentoLiveRow/SportEvent die de rest van de
// Bento-home al gebruikt (zie `VeyraBentoHome.swift`/`VeyraBentoHomeIOS.swift`).

import SwiftUI

/// Wat voor moment dit is -- bepaalt de kaartindeling (zie `VeyraContextRibbon.content`),
/// los van `NodeKind` (verleden/nu/toekomst), dat de kleur/nadruk bepaalt.
nonisolated enum VeyraRibbonContentKind: Sendable {
    case continueWatching, upcoming, live, sport, release
}

nonisolated struct VeyraRibbonItem: Identifiable {
    let id: String
    let icon: String
    let label: String      // "VERDER KIJKEN" · "VOLGENDE AFLEVERING" · "LIVE NU" · "SPORT"
    let text: String       // Titel van film, serie, programma of wedstrijd
    var detail: String? = nil // Aflevering, zender of starttijd
    var isLive: Bool = false
    var contentKind: VeyraRibbonContentKind = .live
    /// Hoe relevant dit item nú is -- bepaalt de sorteervolgorde bij een
    /// gelijk tijdstip (zie `VeyraContextRibbon.sortedItems`).
    var priority: Double = 50
    /// Wanneer dit moment zich voordoet -- bepaalt de plek in de rail.
    /// `nil` (bv. "verder kijken", geen vast tijdstip) wordt vlak vóór "nu"
    /// getoond, als een plek waar de kijker gebleven is i.p.v. een moment
    /// op de klok.
    var time: Date? = nil
    /// Clearlogo/poster/zenderlogo -- als dat er is, vervangt dat de titeltekst (die staat
    /// er dan al op). Bij sport: het thuisteam-logo, met `secondaryLogoURL` als uitteam.
    var logoURL: URL? = nil
    var secondaryLogoURL: URL? = nil
    /// Achtergrondfoto (backdrop/still) die de hele kaart vult, met de tekst er via een
    /// donkere scrim overheen -- als dit er is, wordt de kaart een "poster"-kaart i.p.v.
    /// de compacte icoon+tekst-kaart (zie `node(_:kind:)`). `nil` = geen foto beschikbaar,
    /// gewoon de compacte kaart (bv. live-kanalen, die geen still hebben).
    var backdropURL: URL? = nil
    /// Competitie-/federatielogo (NFL, Champions League, ...) -- gebruikt als zachte
    /// watermerk-achtergrond voor sportkaarten zonder eigen wedstrijdfoto (zie `node(_:kind:)`).
    var leagueLogoURL: URL? = nil
    /// TMDB-id -- als dit er is, haalt de kaart er zelf genre + score bij op (zie
    /// `RibbonEnrichmentBadge`), voor dezelfde "Better Posters"-info als op de posterrasters.
    /// `nil` = geen id beschikbaar (bv. live-kanalen, sport), dan blijft die badge gewoon weg.
    var tmdbID: Int? = nil
    var isMovie: Bool = true
    /// Lang indrukken: "Niet interessant" (blijvend) -- `nil` = geen menu.
    var onDismiss: (() -> Void)? = nil
    /// Lang indrukken: "Vandaag niet tonen" -- `nil` = geen menu.
    var onSnooze: (() -> Void)? = nil
    let action: () -> Void
}

struct VeyraContextRibbon: View {
    let items: [VeyraRibbonItem]
    let now: Date

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPhone (compact breedte) i.t.t. iPad/Mac (regular) -- duidelijk grotere kaarten en
    /// een opgeruimdere rail zonder tijdslijn-balk, die op een smal scherm vooral extra
    /// visuele ruis toevoegt zonder leesbaarheidswinst.
    private var isCompactPhone: Bool {
        #if os(tvOS)
        false
        #else
        horizontalSizeClass == .compact
        #endif
    }

    private enum NodeKind { case past, now, future }

    private struct Metrics {
        let tagSize: CGFloat
        let titleSize: CGFloat
        let nowTitleSize: CGFloat
        let metaSize: CGFloat
        let iconCircle: CGFloat
        let iconSize: CGFloat
        let cardPaddingH: CGFloat
        let cardPaddingV: CGFloat
        let hPadding: CGFloat
        let vPadding: CGFloat
        let headerSize: CGFloat
        let cardGap: CGFloat
        // Alle kaarten dezelfde breedte i.p.v. per soort moment een eigen bandbreedte --
        // enkel "Live nu" (`cardWidth` telt niet voor `.live`, zie `widthRange`) is bewust
        // een stuk breder, als het meest ter-plekke-relevante moment op de rail.
        let cardWidth: CGFloat
        let liveCardWidth: CGFloat
    }

    // tvOS is 10-voet-UI: duidelijk groter dan op iOS.
    private var metrics: Metrics {
        #if os(tvOS)
        Metrics(tagSize: 20, titleSize: 28, nowTitleSize: 33, metaSize: 21,
                iconCircle: 66, iconSize: 26,
                cardPaddingH: 30, cardPaddingV: 26, hPadding: 44, vPadding: 34, headerSize: 19, cardGap: 24,
                cardWidth: 340, liveCardWidth: 460)
        #else
        if isCompactPhone {
            Metrics(tagSize: 14, titleSize: 19, nowTitleSize: 22, metaSize: 15,
                    iconCircle: 46, iconSize: 19,
                    cardPaddingH: 18, cardPaddingV: 15, hPadding: 20, vPadding: 16, headerSize: 13, cardGap: 14,
                    cardWidth: 235, liveCardWidth: 310)
        } else {
            Metrics(tagSize: 11, titleSize: 15, nowTitleSize: 17, metaSize: 12,
                    iconCircle: 36, iconSize: 15,
                    cardPaddingH: 14, cardPaddingV: 12, hPadding: 20, vPadding: 16, headerSize: 12, cardGap: 12,
                    cardWidth: 190, liveCardWidth: 252)
        }
        #endif
    }

    // Items zonder vast tijdstip (verder kijken) sorteren vlak vóór "nu".
    private let untimedOffset: TimeInterval = 26 * 60

    private func effectiveTime(_ item: VeyraRibbonItem) -> Date {
        item.time ?? now.addingTimeInterval(-untimedOffset)
    }

    private func kind(for item: VeyraRibbonItem) -> NodeKind {
        guard let t = item.time else {
            // "Nieuw uitgebracht" heeft geen zinvol tijdstip (releasedatum ligt allang
            // achter ons) maar is juist een aanmoediging vooruit te kijken, niet iets
            // dat al voorbij is -- dus geen dimstijl zoals "verder kijken".
            return item.contentKind == .release ? .future : .past
        }
        let delta = t.timeIntervalSince(now)
        if abs(delta) <= 150 { return .now }
        return delta < 0 ? .past : .future
    }

    /// Vroegst eerst -- zo staan de kaarten in dezelfde volgorde als hun moment.
    private var sortedItems: [VeyraRibbonItem] {
        items.sorted { effectiveTime($0) < effectiveTime($1) }
    }

    // Alle kaarten precies dezelfde breedte -- ook "Live nu" niet meer apart breder,
    // op uitdrukkelijk verzoek (was eerst bewust breder, nu weer gelijk aan de rest).
    private func widthRange(for item: VeyraRibbonItem, kind: NodeKind) -> (min: CGFloat, max: CGFloat) {
        (metrics.cardWidth, metrics.cardWidth)
    }

    /// Welk item bij het verschijnen gecentreerd staat -- "nu" als dat er is, anders
    /// gewoon het tijdsgewijs dichtstbijzijnde moment, i.p.v. altijd bij het (mogelijk
    /// allang voorbije) eerste item te beginnen.
    private var flowCurrent: VeyraRibbonItem? {
        let ordered = sortedItems
        if let nowItem = ordered.filter({ kind(for: $0) == .now }).max(by: { $0.priority < $1.priority }) {
            return nowItem
        }
        return ordered.min { abs(effectiveTime($0).timeIntervalSince(now)) < abs(effectiveTime($1).timeIntervalSince(now)) }
    }

    /// Gewone, scrollbare tijdlijn -- verleden (gedimd), "nu" (uitgelicht) en toekomst
    /// op één rij, alle kaarten even groot (zie `widthRange`). Bij het verschijnen
    /// scrollt de rij automatisch zodat "nu" gecentreerd in beeld staat, i.p.v. bij het
    /// (mogelijk allang voorbije) eerste item te beginnen.
    var body: some View {
        if !sortedItems.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Circle().fill(VeyraHomeStyle.cyan).frame(width: 8, height: 8)
                        .shadow(color: VeyraHomeStyle.cyan.opacity(0.7), radius: 5)
                    Text("VEYRA NOW")
                        .font(.system(size: metrics.headerSize, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(VeyraHomeStyle.cyan)
                }

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: metrics.cardGap) {
                            ForEach(sortedItems) { item in
                                node(item, kind: kind(for: item))
                                    .id(item.id)
                            }
                        }
                        .padding(.horizontal, 4) // ruimte voor de focus-gloed aan de randen
                        .padding(.top, 10)       // idem, boven -- anders klipt de ScrollView de gloed van een
                                                 // gefocuste kaart helemaal bovenaan de rij.
                        .padding(.bottom, 2)
                    }
                    .scrollClipDisabled()
                    .onAppear {
                        guard let target = flowCurrent?.id else { return }
                        // Op de volgende run-loop-cyclus i.p.v. meteen: bij het eerste
                        // verschijnen heeft de ScrollView zichzelf soms nog niet volledig
                        // opgemeten, en scrollt `scrollTo` dan niet ver genoeg.
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.4)) {
                                proxy.scrollTo(target, anchor: .center)
                            }
                        }
                    }
                }

                timelineTrack
            }
            .padding(.horizontal, metrics.hPadding)
            .padding(.vertical, metrics.vPadding)
        }
    }

    /// Blauwe tijdlijn-balk onder de kaartenrij: een dun overzicht van verleden → nu →
    /// toekomst, met een puls-stip op de relatieve plek van "nu" -- puur decoratief/
    /// oriënterend (niet gekoppeld aan de scrollpositie van de rij erboven, die de
    /// gebruiker vrij op en neer scrolt).
    private var timelineTrack: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(VeyraColors.cyan.opacity(0.25))
                    .frame(height: 3)

                VStack(spacing: 4) {
                    Text("NU")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(VeyraColors.cyan)
                        .fixedSize()

                    Circle()
                        .fill(VeyraColors.cyan)
                        .frame(width: 11, height: 11)
                        .shadow(color: VeyraColors.cyan.opacity(0.8), radius: 6)
                }
                .offset(x: dotOffset(in: proxy.size.width))
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 34)
        .padding(.top, 6)
    }

    /// Houdt het "NU"-label + de stip gecentreerd op de berekende plek, ook aan de
    /// randen van de rail (anders liep het label links/rechts buiten de kaartenrij).
    private func dotOffset(in width: CGFloat) -> CGFloat {
        let halfWidth: CGFloat = 15
        let target = width * nowFraction
        let clamped = max(halfWidth, min(width - halfWidth, target))
        return clamped - halfWidth
    }

    /// Relatieve positie (0...1) van "nu" tussen het eerste en laatste item van de rail --
    /// bepaalt waar de puls-stip op `timelineTrack` staat.
    private var nowFraction: CGFloat {
        let ordered = sortedItems
        guard ordered.count > 1, let current = flowCurrent,
              let index = ordered.firstIndex(where: { $0.id == current.id }) else { return 0 }
        return CGFloat(index) / CGFloat(ordered.count - 1)
    }

    // MARK: - Kaart

    @ViewBuilder
    private func node(_ item: VeyraRibbonItem, kind: NodeKind) -> some View {
        // Twee kaartstijlen i.p.v. één: heeft dit item een achtergrond (film/serie-still,
        // wedstrijdfoto, of bij sport minstens het veld-patroon + competitielogo), dan wordt
        // de kaart zelf die poster met de tekst erover -- geen enkele achtergrond beschikbaar
        // (bv. een live-kanaal, dat enkel een klein zenderlogo heeft), dan blijft de compacte
        // icoon+tekst-kaart van hiervoor gewoon bestaan.
        if let backdrop = item.backdropURL {
            posterNode(item, kind: kind) {
                AsyncImage(url: backdrop) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(typeColor(item).opacity(0.16))
                    }
                }
            }
        } else if item.contentKind == .sport {
            // Geen wedstrijdfoto voor deze wedstrijd (lang niet elke bron levert die) -- dan
            // toch geen kale kaart: hetzelfde veld-patroon + zacht competitielogo dat de
            // Sport-sectie elders al gebruikt (`VeyraSportBackdrop`), i.p.v. steeds hetzelfde
            // generieke icoon.
            posterNode(item, kind: kind) {
                VeyraSportBackdrop(url: nil, seed: item.text, leagueLogoURL: item.leagueLogoURL)
            }
        } else {
            compactNode(item, kind: kind)
        }
    }

    @ViewBuilder
    private func posterNode<Background: View>(_ item: VeyraRibbonItem, kind: NodeKind,
                                                @ViewBuilder background: () -> Background) -> some View {
        let tint = typeColor(item)
        let width = widthRange(for: item, kind: kind).max
        let height = width * 0.64
        Button(action: item.action) {
            // Tekst weer OP de foto, binnen het kader zelf, i.p.v. in een losse balk
            // eronder -- ditmaal met een stevige, altijd-donkere gradient (geen lichte
            // scrim) plus tekstschaduw, zodat de leesbaarheid niet meer afhangt van hoe
            // licht/donker de foto daar toevallig is.
            ZStack(alignment: .bottomLeading) {
                background()
                    .frame(width: width, height: height)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.35), .black.opacity(0.94)],
                    startPoint: .top, endPoint: .bottom
                )

                posterContent(item, kind: kind)
                    .padding(.horizontal, metrics.cardPaddingH * 0.75)
                    .padding(.bottom, metrics.cardPaddingV * 0.55)
            }
            .frame(width: width, height: height)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(tint.opacity(kind == .now ? 0.85 : (kind == .past ? 0.18 : 0.4)),
                                  lineWidth: kind == .now ? 2 : 1)
            )
            .opacity(kind == .past ? 0.75 : 1)
            .animation(.easeOut(duration: 0.3), value: kind)
        }
        .buttonStyle(VeyraRailNodeStyle())
        .modifier(VeyraRibbonDismissMenu(item: item))
    }

    @ViewBuilder
    private func posterContent(_ item: VeyraRibbonItem, kind: NodeKind) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            tagRow(item, kind: kind)
            Text(item.text)
                .font(.system(size: kind == .now ? metrics.nowTitleSize : metrics.titleSize, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = item.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: metrics.metaSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            RibbonEnrichmentBadge(tmdbID: item.tmdbID, isMovie: item.isMovie, fontSize: metrics.metaSize)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Genre + score onder de titel op de "Veyra Now"-kaarten -- dezelfde "Better Posters"-info
    /// als op de Films/Series/Kijklijst-rasters (`VeyraPosterCard`), enkel hier zelf opgehaald
    /// (via `PosterEnrichmentDataStore`) omdat de bronnen van deze rail (Trakt/EPG-achtig) zelf
    /// geen genre/score meeleveren zoals TMDB-lijsten dat doen.
    private struct RibbonEnrichmentBadge: View {
        let tmdbID: Int?
        let isMovie: Bool
        let fontSize: CGFloat

        @AppStorage(PosterEnrichmentDefaults.modeKey)
        private var enrichmentSourceRaw = PosterEnrichmentMode.betterPosters.rawValue
        @AppStorage(PosterEnrichmentDefaults.showGenreKey)
        private var showGenre = true
        @AppStorage(PosterEnrichmentDefaults.showRatingKey)
        private var showRating = true

        @State private var genre: String?
        @State private var rating: Double?

        private var enrichmentSource: PosterEnrichmentMode {
            PosterEnrichmentMode(rawValue: enrichmentSourceRaw) ?? .off
        }

        private var text: String? {
            guard enrichmentSource == .betterPosters else { return nil }
            var parts: [String] = []
            if showGenre, let genre { parts.append(genre) }
            if showRating, let rating, rating > 0 { parts.append(String(format: "★ %.1f", rating)) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }

        var body: some View {
            // `.task` op een `Group` i.p.v. enkel op de `Text` hieronder -- anders hangt de
            // fetch vast aan een view die pas bestaat NADAT genre/score al geladen zijn
            // (`text` is `nil` tot dan), en start de fetch dus nooit.
            Group {
                if let text {
                    Text(text)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                        .lineLimit(1)
                }
            }
            .task(id: tmdbID) { await load() }
        }

        private func load() async {
            guard enrichmentSource == .betterPosters, let tmdbID, genre == nil, rating == nil else { return }
            let result = isMovie
                ? await PosterEnrichmentDataStore.shared.genreAndRating(movieID: tmdbID)
                : await PosterEnrichmentDataStore.shared.genreAndRating(tvID: tmdbID)
            genre = result.genre
            rating = result.rating
        }
    }

    @ViewBuilder
    private func compactNode(_ item: VeyraRibbonItem, kind: NodeKind) -> some View {
        let range = widthRange(for: item, kind: kind)
        let tint = typeColor(item)
        // Zelfde minimumhoogte als de fotozone van de poster-kaarten -- ook al zijn alle
        // kaarten nu even breed, zonder dit zou een korte titel (bv. "Live nu") deze kaart
        // toch een stuk lager maken dan de poster-kaarten ernaast.
        let minHeight: CGFloat = metrics.cardWidth * 0.64
        Button(action: item.action) {
            content(item, kind: kind)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, metrics.cardPaddingH)
                .padding(.vertical, metrics.cardPaddingV)
                .frame(minWidth: range.min, maxWidth: range.max, minHeight: minHeight, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(kind == .now ? 0.20 : (kind == .past ? 0.05 : 0.10)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(kind == .now ? 0.65 : (kind == .past ? 0.12 : 0.28)),
                                      lineWidth: kind == .now ? 1.5 : 1)
                )
                .opacity(kind == .past ? 0.75 : 1)
                .animation(.easeOut(duration: 0.3), value: kind)
        }
        .buttonStyle(VeyraRailNodeStyle())
        .modifier(VeyraRibbonDismissMenu(item: item))
    }

    /// Alleen een lang-indruk-menu tonen als het item er iets voor aanbiedt --
    /// anders opent lang indrukken een leeg menu, en dat oogt kapot.
    private struct VeyraRibbonDismissMenu: ViewModifier {
        let item: VeyraRibbonItem

        func body(content: Content) -> some View {
            if item.onDismiss != nil || item.onSnooze != nil {
                content.contextMenu {
                    if let onSnooze = item.onSnooze {
                        Button { onSnooze() } label: { Label("Vandaag niet tonen", systemImage: "clock.arrow.circlepath") }
                    }
                    if let onDismiss = item.onDismiss {
                        Button(role: .destructive) { onDismiss() } label: { Label("Niet interessant", systemImage: "hand.thumbsdown") }
                    }
                }
            } else {
                content
            }
        }
    }

    /// De vaste kleuridentiteit van een type moment -- "verder kijken" en live
    /// blijven Veyra's cyaan/rood, "volgende aflevering" krijgt violet, sport amber.
    /// Nieuwe types kiezen hier gewoon hun eigen tint bij.
    private func typeColor(_ item: VeyraRibbonItem) -> Color {
        switch item.contentKind {
        case .continueWatching: return VeyraHomeStyle.cyan
        case .upcoming: return Color(red: 0.70, green: 0.57, blue: 0.94)
        case .live: return item.isLive ? VeyraColors.red : VeyraHomeStyle.cyan
        case .sport: return Color(red: 1.0, green: 0.64, blue: 0.20)
        case .release: return Color(red: 0.35, green: 0.82, blue: 0.55)
        }
    }

    /// Elk soort moment krijgt zijn eigen opbouw i.p.v. één generiek sjabloon:
    /// "verder kijken" leest als een compacte afspeelrij (icoon + tekst), sport
    /// centreert rond de titel (vaak twee teams), de rest blijft de vertrouwde
    /// tag/titel/detail-kolom.
    @ViewBuilder
    private func content(_ item: VeyraRibbonItem, kind: NodeKind) -> some View {
        switch item.contentKind {
        case .continueWatching, .upcoming, .release:
            HStack(spacing: metrics.cardPaddingH * 0.6) {
                if let url = item.logoURL {
                    logoImage(url, maxWidth: metrics.iconCircle * 2.6, maxHeight: metrics.iconCircle * 1.3) {
                        typeIcon(item, kind: kind)
                    }
                } else {
                    typeIcon(item, kind: kind)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.label)
                        .font(.system(size: metrics.tagSize * 0.8, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(typeColor(item).opacity(kind == .past ? 0.55 : 1))
                    // Titel staat al op het clearlogo -- die niet dubbel als tekst tonen.
                    if item.logoURL == nil {
                        Text(item.text)
                            .font(.system(size: kind == .now ? metrics.nowTitleSize : metrics.titleSize,
                                          weight: kind == .now ? .bold : .semibold))
                            .foregroundStyle(.white.opacity(kind == .past ? 0.55 : 1))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let detail = item.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: metrics.metaSize, weight: .medium))
                            .foregroundStyle(.white.opacity(kind == .past ? 0.35 : 0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    RibbonEnrichmentBadge(tmdbID: item.tmdbID, isMovie: item.isMovie, fontSize: metrics.metaSize * 0.9)
                }
            }

        case .live:
            HStack(spacing: metrics.cardPaddingH * 0.6) {
                if let url = item.logoURL {
                    logoImage(url, maxWidth: metrics.iconCircle * 1.3, maxHeight: metrics.iconCircle * 1.3) {
                        typeIcon(item, kind: kind)
                    }
                    .frame(width: metrics.iconCircle, height: metrics.iconCircle)
                } else {
                    typeIcon(item, kind: kind)
                }

                VStack(alignment: .leading, spacing: 4) {
                    tagRow(item, kind: kind)
                    Text(item.text)
                        .font(.system(size: kind == .now ? metrics.nowTitleSize : metrics.titleSize,
                                      weight: kind == .now ? .bold : .semibold))
                        .foregroundStyle(.white.opacity(kind == .past ? 0.55 : 1))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = item.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: metrics.metaSize, weight: .medium))
                            .foregroundStyle(.white.opacity(kind == .past ? 0.35 : 0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }

        case .sport:
            VStack(spacing: 8) {
                tagRow(item, kind: kind)
                if let home = item.logoURL, let away = item.secondaryLogoURL {
                    HStack(spacing: 14) {
                        logoImage(home, maxWidth: metrics.iconCircle, maxHeight: metrics.iconCircle) { EmptyView() }
                        Text("–")
                            .font(.system(size: metrics.titleSize, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                        logoImage(away, maxWidth: metrics.iconCircle, maxHeight: metrics.iconCircle) { EmptyView() }
                    }
                } else {
                    Text(item.text)
                        .font(.system(size: kind == .now ? metrics.nowTitleSize : metrics.titleSize,
                                      weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(kind == .past ? 0.55 : 1))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: metrics.metaSize, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(kind == .past ? 0.35 : 0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Clearlogo/poster/zenderlogo met een nette overgang: tot het geladen is (of als het
    /// mislukt) staat gewoon het icoon van het type er al, i.p.v. een lege plek.
    @ViewBuilder
    private func logoImage<Fallback: View>(_ url: URL, maxWidth: CGFloat, maxHeight: CGFloat,
                                            @ViewBuilder fallback: @escaping () -> Fallback) -> some View {
        AsyncImage(url: url) { phase in
            if case .success(let image) = phase {
                image.resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            } else {
                fallback()
            }
        }
    }

    @ViewBuilder
    private func typeIcon(_ item: VeyraRibbonItem, kind: NodeKind) -> some View {
        ZStack {
            Circle().fill(typeColor(item).opacity(0.16))
            Image(systemName: item.icon)
                .font(.system(size: metrics.iconSize, weight: .bold))
                .foregroundStyle(typeColor(item))
        }
        .frame(width: metrics.iconCircle, height: metrics.iconCircle)
    }

    @ViewBuilder
    private func tagRow(_ item: VeyraRibbonItem, kind: NodeKind) -> some View {
        HStack(spacing: 5) {
            if item.isLive {
                Circle().fill(VeyraColors.red).frame(width: 6, height: 6)
                    .shadow(color: VeyraColors.red.opacity(0.7), radius: 4)
            }
            Text(item.label)
                .font(.system(size: metrics.tagSize, weight: .heavy, design: .rounded))
                .tracking(1.1)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(typeColor(item).opacity(kind == .past ? 0.55 : 1))
    }

    private struct VeyraRailNodeStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            Inner(configuration: configuration)
        }

        private struct Inner: View {
            let configuration: ButtonStyleConfiguration
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(VeyraHomeStyle.cyan, lineWidth: isFocused ? 3 : 0)
                    )
                    .shadow(color: isFocused ? VeyraHomeStyle.cyan.opacity(0.5) : .clear, radius: 16)
                    .scaleEffect(isFocused ? 1.06 : (configuration.isPressed ? 0.97 : 1))
                    .opacity(configuration.isPressed ? 0.85 : 1)
                    .zIndex(isFocused ? 1 : 0)
                    .animation(.easeOut(duration: 0.16), value: isFocused)
                    .focusEffectDisabled()
            }
        }
    }
}
