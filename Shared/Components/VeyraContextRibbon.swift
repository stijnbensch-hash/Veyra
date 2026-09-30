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

/// Waaróm dit item nu op de rail staat -- de korte, mensvriendelijke reden
/// ("Nog 1 aflevering", "Nu live", "Begint over 12 min", ...), belangrijker
/// om te tonen dan de genre/beoordeling-badge (`RibbonEnrichmentBadge`).
/// Puur informatief voor de aanroeper (`reasonText` op `VeyraRibbonItem` is
/// de vrije tekst die effectief getoond wordt); dit enum staat er los van
/// zodat een aanroeper desgewenst ook zelf op reden kan filteren/loggen.
nonisolated enum VeyraNowReason: Sendable {
    case continueWatching, almostFinished, newEpisode, newRelease, live, startsSoon, upcoming
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
    /// Korte reden waarom dit item NU relevant is, bv. "Nog 1 aflevering", "Nu live",
    /// "Begint over 12 min", "Vandaag uitgebracht" -- belangrijker dan genre/beoordeling,
    /// dus als dit gezet is toont de kaart het prominent boven de gewone `detail`-regel.
    /// `nil` = geen specifieke reden (bv. gewoon "verder kijken" zonder bijzonderheid).
    var reason: VeyraNowReason? = nil
    var reasonText: String? = nil
    /// `true` als `backdropURL` een poster is (i.p.v. een échte backdrop) waar de titel al
    /// in de afbeelding zelf gebakken zit (TMDB-posters bevatten vaak een titel-graphic) --
    /// dan geen eigen logo/titel er nog eens overheen zetten (zie `posterContent`).
    var titleBakedIntoArt: Bool = false
    /// Lang indrukken: "Niet interessant" (blijvend) -- `nil` = geen menu.
    var onDismiss: (() -> Void)? = nil
    /// Lang indrukken: "Vandaag niet tonen" -- `nil` = geen menu.
    var onSnooze: (() -> Void)? = nil
    let action: () -> Void
}

/// Async ClearLogo-ophaler voor Veyra Now-kaarten die zelf geen `logoURL` meekrijgen
/// (bv. "Nieuw uitgebracht", dat alleen een tmdbID heeft) -- zelfde bron als
/// `VeyraClearLogo` op de detailschermen, hier lokaal zodat de rail geen losse
/// `MediaItem` model hoeft te bouwen/doorgeven.
private struct RibbonClearLogo<Fallback: View>: View {
    let tmdbID: Int
    let isMovie: Bool
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    let fallback: () -> Fallback

    @State private var logoURL: URL?

    init(tmdbID: Int, isMovie: Bool, maxWidth: CGFloat, maxHeight: CGFloat,
         @ViewBuilder fallback: @escaping () -> Fallback) {
        self.tmdbID = tmdbID
        self.isMovie = isMovie
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.fallback = fallback
    }

    var body: some View {
        Group {
            if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                    } else {
                        fallback()
                    }
                }
            } else {
                fallback()
            }
        }
        .task(id: tmdbID) {
            logoURL = await ClearLogoService.logoURL(for: MediaItem(title: "", type: isMovie ? .movie : .series, tmdbID: tmdbID))
        }
    }
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
        // Verleden/toekomst dezelfde breedte -- enkel "nu" (`nowCardWidth`, zie
        // `widthRange`) is duidelijk breder: het meest ter-plekke-relevante moment op
        // de rail verdient meer ruimte dan wat al voorbij is of nog moet komen.
        let cardWidth: CGFloat
        let nowCardWidth: CGFloat
    }

    // tvOS is 10-voet-UI: duidelijk groter dan op iOS.
    private var metrics: Metrics {
        #if os(tvOS)
        Metrics(tagSize: 20, titleSize: 28, nowTitleSize: 33, metaSize: 21,
                iconCircle: 66, iconSize: 26,
                cardPaddingH: 30, cardPaddingV: 26, hPadding: 44, vPadding: 34, headerSize: 19, cardGap: 24,
                cardWidth: 320, nowCardWidth: 460)
        #else
        if isCompactPhone {
            Metrics(tagSize: 14, titleSize: 19, nowTitleSize: 22, metaSize: 15,
                    iconCircle: 46, iconSize: 19,
                    cardPaddingH: 18, cardPaddingV: 15, hPadding: 20, vPadding: 16, headerSize: 13, cardGap: 14,
                    cardWidth: 235, nowCardWidth: 310)
        } else {
            Metrics(tagSize: 11, titleSize: 15, nowTitleSize: 17, metaSize: 12,
                    iconCircle: 36, iconSize: 15,
                    cardPaddingH: 14, cardPaddingV: 12, hPadding: 20, vPadding: 16, headerSize: 12, cardGap: 12,
                    cardWidth: 190, nowCardWidth: 252)
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

    // "Nu" duidelijk breder dan verleden/toekomst (Veyra Now fase 1) -- niet per
    // brontype (`.live` kreeg dat vroeger apart, nu gelijk aan de rest van `.now`).
    private func widthRange(for item: VeyraRibbonItem, kind: NodeKind) -> (min: CGFloat, max: CGFloat) {
        let width = kind == .now ? metrics.nowCardWidth : metrics.cardWidth
        return (width, width)
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
                        // Kaart + tijdmarkering nu SAMEN in één kolom per item, allebei in
                        // dezelfde HStack/ScrollView (Veyra Now fase 2) -- de tijdlijn scrolt
                        // zo letterlijk mee met de kaarten i.p.v. een losse, onafhankelijke
                        // balk eronder die niet meebewoog met wat je net aan het bekijken was.
                        HStack(alignment: .top, spacing: metrics.cardGap) {
                            ForEach(sortedItems) { item in
                                let itemKind = kind(for: item)
                                VStack(alignment: .leading, spacing: 10) {
                                    node(item, kind: itemKind)
                                    timelineMarker(for: item, kind: itemKind,
                                                   width: widthRange(for: item, kind: itemKind).max)
                                }
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
            }
            .padding(.horizontal, metrics.hPadding)
            .padding(.vertical, metrics.vPadding)
        }
    }

    /// Eén korte klokttijd (of "NU") per kaart, met een stukje tijdlijn erboven --
    /// samen vormen die per-kaart-segmenten, allemaal in dezelfde HStack als de kaarten
    /// zelf, de doorlopende tijdlijn (Veyra Now fase 2). Geen eigen `GeometryReader`/
    /// absolute positionering meer nodig: de tijdlijn IS nu gewoon de rij.
    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// `nil` tijdstip (bv. "verder kijken", geen vaste klokttijd) toont geen klokttijd --
    /// het tijdstip-tikje/lijntje blijft wel staan, voor visuele doorlopendheid van de rail.
    private func timeLabel(for item: VeyraRibbonItem, kind: NodeKind) -> String {
        if kind == .now { return "NU" }
        guard let time = item.time else { return "" }
        return Self.clockFormatter.string(from: time)
    }

    @ViewBuilder
    private func timelineMarker(for item: VeyraRibbonItem, kind: NodeKind, width: CGFloat) -> some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(kind == .now ? VeyraColors.cyan.opacity(0.9) : VeyraColors.cyan.opacity(0.22))
                .frame(height: kind == .now ? 3 : 2)

            HStack(spacing: 4) {
                if kind == .now {
                    Circle()
                        .fill(VeyraColors.cyan)
                        .frame(width: 6, height: 6)
                        .shadow(color: VeyraColors.cyan.opacity(0.8), radius: 5)
                }
                let label = timeLabel(for: item, kind: kind)
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: metrics.metaSize * 0.72, weight: kind == .now ? .bold : .medium))
                        .tracking(kind == .now ? 1 : 0)
                        .foregroundStyle(kind == .now ? VeyraColors.cyan : .white.opacity(kind == .past ? 0.32 : 0.55))
                }
            }
        }
        .frame(width: width)
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
                    // Verleden: "weinig border" (spec) -- duidelijk dunner/vager dan de
                    // rustende rand van nu/toekomst, niet enkel iets minder opaak.
                    .strokeBorder(tint.opacity(kind == .now ? 0.85 : (kind == .past ? 0.12 : 0.4)),
                                  lineWidth: kind == .now ? 2 : 1)
            )
            // Verleden: gedimd én ontverzadigd (Veyra Now fase 1) -- nog steeds volledig
            // aantikbaar, dus bewust GEEN `.disabled`, enkel visueel teruggeschroefd.
            .opacity(kind == .past ? 0.6 : 1)
            .saturation(kind == .past ? 0.55 : 1)
            .animation(.easeOut(duration: 0.3), value: kind)
        }
        .buttonStyle(VeyraRailNodeStyle())
        .modifier(VeyraRibbonDismissMenu(item: item))
    }

    @ViewBuilder
    private func posterContent(_ item: VeyraRibbonItem, kind: NodeKind) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            tagRow(item, kind: kind)
            // Sport: thuis- vs uitploeg naast elkaar i.p.v. één "clearlogo" -- een los teamlogo
            // zou anders ten onrechte als hét logo van de wedstrijd ogen.
            if item.contentKind == .sport, let home = item.logoURL, let away = item.secondaryLogoURL {
                HStack(spacing: 14) {
                    logoImage(home, maxWidth: 56, maxHeight: 56) { EmptyView() }
                    Text("–")
                        .font(.system(size: metrics.titleSize, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    logoImage(away, maxWidth: 56, maxHeight: 56) { EmptyView() }
                }
            } else if item.titleBakedIntoArt {
                // Titel staat al op de afbeelding zelf (posterfallback) -- geen tweede
                // logo/titel erover heen zetten, dat gaf een dubbele titel.
                EmptyView()
            } else if let logoURL = item.logoURL {
                // ClearLogo i.p.v. titeltekst als die er is (Veyra Now fase 1) -- de titel
                // staat dan al leesbaar op het logo, dubbele tekst oogt rommelig.
                logoImage(logoURL, maxWidth: 220, maxHeight: kind == .now ? 66 : 50) {
                    posterTitleText(item, kind: kind)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let tmdbID = item.tmdbID {
                // Geen logoURL rechtstreeks van de bron (bv. "Nieuw uitgebracht") -- zelfde
                // TMDB-clearlogo als op de detailschermen (`VeyraClearLogo`), hier async opgehaald.
                RibbonClearLogo(tmdbID: tmdbID, isMovie: item.isMovie, maxWidth: 220, maxHeight: kind == .now ? 66 : 50) {
                    posterTitleText(item, kind: kind)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                posterTitleText(item, kind: kind)
            }
            // Reden waarom dit item NU relevant is -- belangrijker dan genre/beoordeling,
            // dus vóór de `detail`-regel en de enrichment-badge (Veyra Now fase 1).
            if let reasonText = item.reasonText, !reasonText.isEmpty {
                Text(reasonText)
                    .font(.system(size: metrics.metaSize, weight: .bold))
                    .foregroundStyle(VeyraHomeStyle.cyan)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                    .lineLimit(1)
            }
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

    @ViewBuilder
    private func posterTitleText(_ item: VeyraRibbonItem, kind: NodeKind) -> some View {
        Text(item.text)
            .font(.system(size: kind == .now ? metrics.nowTitleSize : metrics.titleSize, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
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
        // Zelfde minimumhoogte als de fotozone van de poster-kaarten, geschaald met de
        // eigen breedte van dít kaartje (nu-kaarten zijn breder, zie `widthRange`) --
        // anders zou een korte titel (bv. "Live nu") deze kaart een stuk lager maken
        // dan de poster-kaarten ernaast.
        let minHeight: CGFloat = range.max * 0.64
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
                        .strokeBorder(tint.opacity(kind == .now ? 0.65 : (kind == .past ? 0.10 : 0.28)),
                                      lineWidth: kind == .now ? 1.5 : 1)
                )
                // Verleden: gedimd én ontverzadigd (Veyra Now fase 1) -- nog steeds volledig
                // aantikbaar, dus bewust GEEN `.disabled`, enkel visueel teruggeschroefd.
                .opacity(kind == .past ? 0.6 : 1)
                .saturation(kind == .past ? 0.55 : 1)
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

    /// Veyra's kleuridentiteit: cyaan is de default voor elk type moment, rood is
    /// gereserveerd voor "nu live" -- GEEN apart contenttype-kleurtje per soort (dat was
    /// eerst violet/amber/groen per `contentKind`, maar contenttype hoort te blijken uit
    /// layout/icoon/label, niet uit kleur, zie Veyra's stijlregels). "Verleden" krijgt geen
    /// eigen kleur hier: dat wordt puur via opacity/saturation gedimd (zie `node(_:kind:)`).
    private func typeColor(_ item: VeyraRibbonItem) -> Color {
        item.isLive ? VeyraColors.red : VeyraHomeStyle.cyan
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
                    if let reasonText = item.reasonText, !reasonText.isEmpty {
                        Text(reasonText)
                            .font(.system(size: metrics.metaSize, weight: .bold))
                            .foregroundStyle(VeyraHomeStyle.cyan.opacity(kind == .past ? 0.55 : 1))
                            .lineLimit(1)
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
                    if let reasonText = item.reasonText, !reasonText.isEmpty {
                        Text(reasonText)
                            .font(.system(size: metrics.metaSize, weight: .bold))
                            .foregroundStyle(VeyraHomeStyle.cyan.opacity(kind == .past ? 0.55 : 1))
                            .lineLimit(1)
                    }
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
                if let reasonText = item.reasonText, !reasonText.isEmpty {
                    Text(reasonText)
                        .font(.system(size: metrics.metaSize, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(VeyraHomeStyle.cyan.opacity(kind == .past ? 0.55 : 1))
                        .lineLimit(1)
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
                // Veyra Now fase 1: subtielere focus -- cyaan rand + zachte gloed + kleine
                // schaal (1.05), i.p.v. een dikke 3pt rand met zware gloed en grote schaal.
                configuration.label
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(VeyraHomeStyle.cyan, lineWidth: isFocused ? 2 : 0)
                    )
                    .shadow(color: isFocused ? VeyraHomeStyle.cyan.opacity(0.4) : .clear, radius: 12)
                    .scaleEffect(isFocused ? 1.05 : (configuration.isPressed ? 0.97 : 1))
                    .opacity(configuration.isPressed ? 0.85 : 1)
                    .zIndex(isFocused ? 1 : 0)
                    .animation(.easeOut(duration: 0.16), value: isFocused)
                    .focusEffectDisabled()
            }
        }
    }
}
