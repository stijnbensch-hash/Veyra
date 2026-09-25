import SwiftUI

struct VeyraPosterCard: View {
    let title: String
    let url: URL?
    var symbol = "film"
    var width: CGFloat = 220
    /// Eerste/belangrijkste genre voor deze titel, bv. "Actie" — via
    /// `TMDBGenreNames.firstMovieName(for:)`/`firstTVName(for:)`. `nil` als onbekend.
    var genre: String? = nil
    /// TMDB-score (0-10), bv. 7.2. `nil` als onbekend.
    var rating: Double? = nil
    /// Naam van de bron (addon/mediaserver/IPTV-provider), alleen getoond
    /// als dit item niet aan TMDB gekoppeld kon worden — zodat duidelijk is
    /// waar de titel vandaan komt als de rijke TMDB-info ontbreekt.
    var sourceLabel: String? = nil
    /// Releasejaar, bv. "2024" — enkel getoond als "Releasejaar tonen" (Instellingen → Algemeen) aan staat.
    var year: String? = nil
    /// TMDB-id van deze titel — nodig voor Leeftijdsclassificatie, Trendlabels en Resterende
    /// afleveringen (die slaan een titel op via id, niet via genre/rating die al meekomen).
    /// Zonder id blijven die drie badges gewoon leeg; Genre/Beoordeling werken ook zonder id.
    var tmdbID: Int? = nil
    var isMovie: Bool = true
    /// Ruwe releasedatum ("yyyy-MM-dd", zoals TMDB die teruggeeft) — enkel gebruikt om het
    /// "Nieuw"-trendlabel te bepalen (recent uitgebracht), niet voor weergave.
    var releaseDateRaw: String? = nil
    /// "Bekeken"-vinkje (Trakt) -- hier als parameter i.p.v. de aanroeper `.traktWatchedCheckmark(...)`
    /// erna te laten plakken: dat plakte het vinkje aan de rechterbovenhoek van de HELE kaart (incl. het
    /// trendlabel/genre-rijtje errond), waardoor het bij een trendlabel los van de poster kwam te hangen.
    /// Nu zit het vinkje in de overlay van de posterafbeelding zelf, dus altijd exact op de poster.
    var watchedTarget: TraktWatchedTarget? = nil
    var watchedPartialDisplay: VeyraWatchedPartialDisplay = .hidden

    @AppStorage(GeneralSettingsDefaults.showReleaseYearKey)
    private var showReleaseYear = true

    @AppStorage(PosterEnrichmentDefaults.modeKey)
    private var enrichmentSourceRaw = PosterEnrichmentMode.off.rawValue
    @AppStorage(PosterEnrichmentDefaults.showGenreKey)
    private var showGenre = true
    @AppStorage(PosterEnrichmentDefaults.showRatingKey)
    private var showRating = true
    @AppStorage(PosterEnrichmentDefaults.showAgeRatingKey)
    private var showAgeRating = false
    @AppStorage(PosterEnrichmentDefaults.showTrendLabelsKey)
    private var showTrending = false

    @ObservedObject private var enrichmentStore = PosterEnrichmentDataStore.shared
    @State private var certification: String?

    // Kader + gloed bij focus horen uitsluitend rond de posterafbeelding, niet rond de
    // hele kaart (incl. trendlabel/genre-tekst errond) -- vandaar hier gelezen i.p.v. in
    // de `buttonStyle` van de aanroeper (zie `VeyraPosterFocusStyle`, die enkel nog een
    // lichte vergroting van de hele kaart doet).
#if os(tvOS)
    @Environment(\.isFocused) private var isFocused
#endif

    private var enrichmentSource: PosterEnrichmentMode {
        PosterEnrichmentMode(rawValue: enrichmentSourceRaw) ?? .off
    }

    private var enrichmentText: String? {
        guard enrichmentSource == .betterPosters else { return nil }
        var parts: [String] = []
        if showGenre, let genre { parts.append(genre) }
        if showRating, let rating, rating > 0 { parts.append(String(format: "★ %.1f", rating)) }
        if showAgeRating, let certification { parts.append(certification) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Trendlabel, gecentreerd bovenaan de poster, los van genre/beoordeling onderaan —
    /// zelfde drie varianten als de referentie-app (BetterPoster): "#N" (rangschikking in de
    /// trendinglijst van vandaag), "Trending" (trending maar niet in de top), of "Nieuw"
    /// (minder dan 21 dagen geleden uitgebracht). Hoogstens één label per poster.
    private var trendBadgeText: String? {
        guard enrichmentSource == .betterPosters, showTrending, let tmdbID else { return nil }
        if let rank = enrichmentStore.trendingRank(id: tmdbID, isMovie: isMovie) {
            return rank <= 3 ? "#\(rank)" : "Trending"
        }
        if isRecentlyReleased { return "Nieuw" }
        return nil
    }

    private var isRecentlyReleased: Bool {
        guard let releaseDateRaw else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: releaseDateRaw) else { return false }
        let interval = Date().timeIntervalSince(date)
        return interval >= 0 && interval < 21 * 86_400
    }

    /// Haalt de leeftijdsclassificatie eenmalig op zodra de badge aan staat en er een id is —
    /// niet in `enrichmentText` zelf, want dat is een synchrone computed property.
    private func loadCertificationIfNeeded() async {
        guard enrichmentSource == .betterPosters, showAgeRating, let tmdbID, certification == nil else { return }
        certification = await (isMovie ? enrichmentStore.certification(movieID: tmdbID) : enrichmentStore.certification(tvID: tmdbID))
    }

    // Op de smalle iOS-postercards (112pt) liep de badge-tekst ("Actie ·
    // ★ 7.8") tegen de rand aan en werd afgekapt met "…" — op tvOS (220pt+)
    // is daar meer dan genoeg ruimte voor. Kleinere badge-tekst, minder
    // opvulling en een schaalfactor lossen dat op zonder de inhoud te
    // moeten inkorten.
    /// Subtiele pil voor het trendlabel bovenaan en de genre/beoordeling-lijn
    /// onderaan (dezelfde vorm voor beide): een gedempte, donkere vulling die
    /// met de poster meegaat i.p.v. een felle cyaan/rode vlek, met daaromheen
    /// een dun kader in Veyra's eigen cyaan->rood-verloop als enige accent.
    private var posterBadgeFill: Color { .black.opacity(0.45) }
    private var posterBadgeBorder: LinearGradient { VeyraFrame.resting }

#if os(tvOS)
    private var enrichmentFontSize: CGFloat { 16 }
    private var enrichmentHPadding: CGFloat { 10 }
    private var enrichmentVPadding: CGFloat { 6 }
    private var enrichmentTextFontSize: CGFloat { 19 }
    private var trendBadgeFontSize: CGFloat { 19 }
#else
    private var enrichmentFontSize: CGFloat { 9 }
    private var enrichmentHPadding: CGFloat { 6 }
    private var enrichmentVPadding: CGFloat { 3 }
    private var enrichmentTextFontSize: CGFloat { 14 }
    private var trendBadgeFontSize: CGFloat { 12 }
#endif

    // Op tvOS bekijk je dit van op de bank (10-foot UI), op iOS hou je het
    // vast — dezelfde tvOS-maten op een telefoon gaven een los, blokkerig
    // 2-koloms grid met veel te grote titels. Op iOS dus overal kleiner en
    // subtieler, met een zachte schaduw voor wat diepte i.p.v. een zware
    // gradient.
#if os(tvOS)
    private var titleFontSize: CGFloat { 22 }
    private var titleHeight: CGFloat { 56 }
    private var gradientHeight: CGFloat { 90 }
    private var cardPadding: CGFloat { 8 }
    private var stackSpacing: CGFloat { 12 }
#else
    private var titleFontSize: CGFloat { 13 }
    private var titleHeight: CGFloat { 34 }
    private var gradientHeight: CGFloat { 44 }
    private var cardPadding: CGFloat { 4 }
    private var stackSpacing: CGFloat { 6 }
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: stackSpacing) {
            // Altijd dezelfde Text renderen (nooit conditioneel weglaten) en enkel de
            // zichtbaarheid via opacity regelen: een frame-hoogte op een conditionele
            // rij bleek in de praktijk niet altijd exact gelijk uit te komen tussen
            // "met tekst" en "zonder tekst" (afrondingsverschillen in de layout-engine),
            // waardoor de poster errond toch een paar punten verschoof. Met altijd
            // dezelfde tekstweergave (zelfde lettertype/opvulling) erin is de eigen
            // grootte van deze rij gegarandeerd identiek, met of zonder echt trendlabel.
            Text(trendBadgeText ?? "Nieuw")
                .font(.system(size: trendBadgeFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, enrichmentHPadding)
                .padding(.vertical, enrichmentVPadding)
                .background(posterBadgeFill, in: Capsule())
                .overlay(Capsule().strokeBorder(posterBadgeBorder, lineWidth: 1))
                .opacity(trendBadgeText == nil ? 0 : 1)
                .frame(maxWidth: .infinity, alignment: .bottom)
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else {
                    ZStack {
                        VeyraColors.surface
                        Image(systemName: symbol).font(.system(size: 42)).foregroundStyle(VeyraColors.secondary)
                    }
                }
            }
            .frame(width: width, height: width * 1.5).clipped()
            .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.poster, style: .continuous))
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                    .frame(height: gradientHeight)
                    .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.poster, style: .continuous))
            }
#if !os(tvOS)
            .shadow(color: .black.opacity(0.28), radius: 6, y: 3)
#endif
            .overlay(alignment: .topLeading) {
                if let sourceLabel {
                    Text(sourceLabel.uppercased())
                        .font(.system(size: enrichmentFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, enrichmentHPadding)
                        .padding(.vertical, enrichmentVPadding)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(6)
                        .frame(maxWidth: width - 12, alignment: .leading)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let watchedTarget {
                    VeyraWatchedCheckmark(target: watchedTarget, partialDisplay: watchedPartialDisplay)
                        .padding(7)
                        .allowsHitTesting(false)
                }
            }
#if os(tvOS)
            // Kader + gloed bij focus, enkel rond de poster -- niet rond de tekstregels
            // errond (zie `VeyraPosterFocusStyle`, die het kader niet meer zelf tekent).
            .overlay(
                RoundedRectangle(cornerRadius: VeyraRadius.poster, style: .continuous)
                    .strokeBorder(VeyraFrame.active, lineWidth: 3)
                    .opacity(isFocused ? 1 : 0)
            )
            .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.35) : .clear, radius: 16, x: -4)
            .shadow(color: isFocused ? VeyraColors.red.opacity(0.22) : .clear, radius: 16, x: 6)
            .animation(.easeOut(duration: 0.16), value: isFocused)
#endif
            // Zelfde altijd-dezelfde-tekst-truc: zonder genre/beoordeling mag de titel
            // niet omhoog kruipen -- dan staan titels in dezelfde rij niet meer op één
            // lijn t.o.v. elkaar.
            Text(enrichmentText ?? "Genre · ★ 0.0")
                .font(.system(size: enrichmentTextFontSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, enrichmentHPadding)
                .padding(.vertical, enrichmentVPadding)
                .background(posterBadgeFill, in: Capsule())
                .overlay(Capsule().strokeBorder(posterBadgeBorder, lineWidth: 1))
                .opacity(enrichmentText == nil ? 0 : 1)
                .frame(maxWidth: .infinity, alignment: .top)
            HStack(alignment: .top, spacing: 6) {
                Text(title).font(.system(size: titleFontSize, weight: .medium)).foregroundStyle(.white)
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .topLeading)

                if showReleaseYear, let year, !year.isEmpty {
                    Text(year).font(.system(size: titleFontSize, weight: .medium)).foregroundStyle(VeyraColors.cyan)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }
            .frame(height: titleHeight, alignment: .topLeading)
        }.frame(width: width).padding(cardPadding)
        .task(id: tmdbID) { await loadCertificationIfNeeded() }
    }
}

struct VeyraPosterBadge: View {
    let title: String
    var symbol: String? = nil
    var accent: Color = VeyraColors.cyan
    var fontSize: CGFloat = 15

    var body: some View {
        HStack(spacing: 7) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: fontSize - 1, weight: .bold))
                    .foregroundStyle(accent)
            } else {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
            }

            Text(title.uppercased())
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .tracking(0.7)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Color(red: 0.015, green: 0.025, blue: 0.038).opacity(0.94),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(accent.opacity(0.78), lineWidth: 1.25)
        }
        .shadow(color: .black.opacity(0.62), radius: 8, y: 3)
    }
}
