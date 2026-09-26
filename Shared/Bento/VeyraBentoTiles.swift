// VeyraBentoTiles.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Inhoud van de zes bento-tegels, in de Veyra-stijl (glas · cyaan accent · rood alleen voor live ·
// tijdlijn-lijn onderaan elk beeldkader). De platformbestanden geven de tegel zijn knop, focus en formaat.
// `compact` = false: tvOS-maten · true: telefoon/tablet.
// Vereist: VeyraBentoStyle.swift, VeyraBentoModel.swift, VeyraBentoSportViews.swift (SourceHealth.sportTint).

import SwiftUI

// MARK: - Bouwstenen

/// Kleine hoofdletterkop van een tegel, optioneel met (rode) live-stip en een rechter bijschrift.
struct VeyraBentoLabel: View {
    let title: String
    var trailing: String? = nil
    var liveDot = false
    var compact = false
    var smallTrailing = false

    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            if liveDot {
                Circle().fill(VeyraHomeStyle.live)
                    .frame(width: compact ? 8 : 12, height: compact ? 8 : 12)
                    .shadow(color: VeyraHomeStyle.live, radius: 4)
            }
            Text(title)
                .font(.system(size: compact ? 12 : 21, weight: .bold))
                .tracking(compact ? 1.6 : 3)
                .textCase(.uppercase)
                .foregroundStyle(liveDot ? Color.white : VeyraHomeStyle.dim)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(smallTrailing ? .system(size: compact ? 10 : 15, weight: .medium) : (compact ? .caption : .title3))
                    .foregroundStyle(VeyraHomeStyle.dim)
                    .lineLimit(1)
            }
        }
    }
}

private struct VeyraBentoPanel<Content: View>: View {
    var compact = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(compact ? 14 : 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(VeyraFrame.fill)
            .foregroundStyle(.white)
    }
}

// MARK: - Verder kijken

/// Grote kaart: beeld + (kleine) clearlogo/titel, aflevering en resterende tijd, cyaan voortgangslijn.
struct VeyraBentoContinueHeroContent: View {
    let item: ContinueItem
    var compact = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VeyraArt(url: item.backdropURL, seed: item.title)
            LinearGradient(colors: [.black.opacity(0.40), .clear, .black.opacity(0.92)],
                           startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: compact ? 3 : 8) {
                VeyraTitleLogo(title: item.title, logoURL: item.logoURL,
                               size: compact ? 16 : 28, maxLogoHeight: compact ? 32 : 60)
                Text(item.baseMetaText)
                    .font(compact ? .caption.weight(.semibold) : .title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                // Alleen tonen (en dus ook alleen dan de VStack-spacing
                // eronder reserveren) als er iets in staat -- bij een film
                // (geen episodeTitle/aantallen) blijft de onderste tekst zo
                // even compact als bij een serie, i.p.v. een lege regel met
                // dode ruimte eronder.
                if item.episodeTitle != nil || item.countsText != nil {
                    HStack(spacing: compact ? 8 : 14) {
                        if let episodeTitle = item.episodeTitle {
                            Text(episodeTitle)
                                .font(compact ? .caption2 : .callout)
                                .foregroundStyle(VeyraHomeStyle.dim)
                                .lineLimit(1)
                        }
                        if let counts = item.countsText {
                            Text(counts)
                                .font(.system(size: compact ? 13 : 20, weight: .semibold))
                                .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.9))
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                }
            }
            .padding(.horizontal, compact ? 14 : 28)
            .padding(.bottom, compact ? 12 : 26)
            .padding(.trailing, compact ? 44 : 84)
        }
        .overlay(alignment: .topLeading) {
            VeyraBentoLabel(title: "Verder kijken", compact: compact)
                .fixedSize()
                .padding(.leading, compact ? 14 : 28)
                .padding(.top, compact ? 12 : 22)
                .foregroundStyle(.white.opacity(0.9))
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "play.fill")
                .font(.system(size: compact ? 14 : 24, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: compact ? 34 : 60, height: compact ? 34 : 60)
                .background(Color.white, in: Circle())
                .padding(compact ? 12 : 24)
                .padding(.bottom, compact ? 2 : 4)
        }
        .overlay(alignment: .bottom) {
            if item.progress > 0 { VeyraHairline(progress: item.progress, height: compact ? 3 : 4) }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Verder kijken: \(item.title), \(item.metaText)")
    }
}

/// Balk voor de andere titels die je verder kunt kijken: het beeld vult de balk, tekst er klein overheen.
struct VeyraBentoContinueMiniContent: View {
    let item: ContinueItem
    var compact = false
    var thumbnailWidth: CGFloat? = nil
    var cornerRadius: CGFloat = 22

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            ZStack {
                // Enkel de afbeelding in het kader -- geen titeltekst/clearlogo meer overheen
                // (die staat, samen met de meta-tekst, al los onder het kader).
                VeyraArt(url: item.bannerURL ?? item.backdropURL, seed: item.title)
                LinearGradient(colors: [.black.opacity(0.45), .clear, .black.opacity(0.10)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottom) {
                if item.progress > 0 { VeyraHairline(progress: item.progress, height: compact ? 3 : 4) }
            }
            // Het cyaan/rode kader zit alleen rond de banner, niet rond de tekst eronder.
            .clipShape(shape)
            .overlay(shape.strokeBorder(isFocused ? VeyraFrame.active : VeyraFrame.resting,
                                        lineWidth: isFocused ? 3 : 1.5))
            .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.32) : Color.black.opacity(0.3),
                    radius: isFocused ? 22 : 14, x: isFocused ? -5 : 0, y: isFocused ? 3 : 10)
            .shadow(color: isFocused ? VeyraColors.red.opacity(0.20) : .clear, radius: 22, x: 8, y: 3)

            // Zelfde onderschriftstijl als Binnenkort: clearlogo links, cyaan info rechts.
            HStack(alignment: .center, spacing: compact ? 8 : 14) {
                VeyraTitleLogo(title: item.title, logoURL: item.logoURL,
                               size: compact ? 15 : 20, maxLogoHeight: compact ? 26 : 38)

                Text(compact ? item.shortMetaText : item.metaText)
                    .font(.system(size: compact ? 14 : 18, weight: .bold))
                    .foregroundStyle(VeyraHomeStyle.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, compact ? 10 : 14)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.metaText)")
    }
}

// MARK: - Live nu

/// Kader met kop; de rijen (elk een eigen knop) worden door het scherm aangeleverd.
struct VeyraBentoLiveList<Rows: View>: View {
    var compact = false
    @ViewBuilder var rows: Rows

    var body: some View {
        VeyraBentoPanel(compact: compact) {
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                VeyraBentoLabel(title: "Live nu", liveDot: true, compact: compact)
                VStack(spacing: compact ? 2 : 4) { rows }
                Spacer(minLength: 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 22 : 30, style: .continuous))
        .veyraGlassSurface(cornerRadius: compact ? 22 : 30)
    }
}

/// Eén zender in "Live nu": logo (eigen logo uit Live TV), naam, programma en voortgang.
struct VeyraBentoLiveRowContent: View {
    let row: BentoLiveRow
    var compact = false

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 10 : 16) {
            channelLogo

            VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                HStack(spacing: compact ? 5 : 8) {
                    if row.isSports {
                        Circle().fill(VeyraHomeStyle.live).frame(width: compact ? 6 : 10, height: compact ? 6 : 10)
                    }
                    (
                        Text("\(row.title) · ")
                            .font(compact ? .caption : .callout)
                        + Text("nog \(row.remainingMinutes) min")
                            .font(compact ? .caption2 : .footnote)
                    )
                        .foregroundStyle(VeyraHomeStyle.dim)
                        .lineLimit(1)
                }
                // I.p.v. de zendernaam: het eerstvolgende programma, in
                // dezelfde tekstgrootte als het huidige programma erboven.
                if let nextTitle = row.nextTitle {
                    Text("Straks: \(nextTitle)")
                        .font(compact ? .caption : .callout)
                        .foregroundStyle(VeyraHomeStyle.dim)
                        .lineLimit(1)
                }
                VeyraHairline(progress: row.progress, tint: row.isSports ? VeyraHomeStyle.live : VeyraHomeStyle.cyan,
                              height: compact ? 3 : 4)
                    .padding(.top, compact ? 3 : 5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Circle().fill(row.health.sportTint).frame(width: compact ? 8 : 12, height: compact ? 8 : 12)
                .accessibilityHidden(true)
        }
        .padding(.vertical, compact ? 6 : 9)
        .padding(.horizontal, compact ? 6 : 14)
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.channelName), \(row.title), nog \(row.remainingMinutes) minuten" + (row.nextTitle.map { ", straks \($0)" } ?? ""))
    }

    private var channelLogo: some View {
        return ZStack {
            if let url = row.logoURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        Image(systemName: "tv").foregroundStyle(VeyraHomeStyle.faint)
                    }
                }
            } else {
                Image(systemName: "tv").foregroundStyle(VeyraHomeStyle.faint)
            }
        }
        .frame(width: compact ? 58 : 112, height: compact ? 38 : 68)
        .accessibilityHidden(true)
    }
}

/// Lege staat: er zijn geen favoriete/recente zenders met programmagegevens.
struct VeyraBentoLiveEmptyContent: View {
    var compact = false

    var body: some View {
        VeyraBentoPanel(compact: compact) {
            VStack(alignment: .leading, spacing: compact ? 6 : 12) {
                VeyraBentoLabel(title: "Live nu", liveDot: true, compact: compact)
                Spacer(minLength: 0)
                Image(systemName: "tv")
                    .font(.system(size: compact ? 24 : 44))
                    .foregroundStyle(VeyraHomeStyle.faint)
                Text("Geen zenders met gids gevonden")
                    .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
                Text("Markeer zenders als favoriet in Live TV om ze hier te zien.")
                    .font(compact ? .caption : .callout)
                    .foregroundStyle(VeyraHomeStyle.dim)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Vandaag

struct VeyraBentoTodayContent: View {
    let today: BentoToday
    let now: Date
    let reminders: Set<String>
    var compact = false

    var body: some View {
        VeyraBentoPanel(compact: compact) {
            VStack(alignment: .leading, spacing: 0) {
                VeyraBentoLabel(title: today.heading, compact: compact)
                    .padding(.bottom, compact ? 4 : 8)
                ForEach(Array(today.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().overlay(Color.white.opacity(0.09)) }
                    itemView(item)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// "Vandaag" · "Morgen" · "vr 26 sep" (zonder uur)
    private func dayLabel(_ item: UpcomingItem) -> String {
        VeyraHomeFormat.when(item.airDate, now: now, dateOnly: true)
    }

    private func itemView(_ item: UpcomingItem) -> some View {
        let on = reminders.contains(item.id)
        let code = item.episodeCode ?? (item.kind == .movie ? "Film" : "Nieuw")
        return VStack(alignment: .leading, spacing: compact ? 3 : 6) {
            HStack(spacing: 8) {
                Text(item.title)
                    .font(.system(size: compact ? 15 : 25, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Image(systemName: on ? "bell.fill" : "bell")
                    .font(compact ? .caption : .callout)
                    .foregroundStyle(on ? VeyraHomeStyle.cyan : VeyraHomeStyle.faint)
            }
            HStack(spacing: 8) {
                Text(code)
                    .font(compact ? .caption : .callout)
                    .foregroundStyle(VeyraHomeStyle.dim)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(dayLabel(item))
                    .font(.system(size: compact ? 11 : 17, weight: .bold))
                    .foregroundStyle(VeyraHomeStyle.cyan)
                    .lineLimit(1)
                    .padding(.horizontal, compact ? 8 : 14)
                    .padding(.vertical, compact ? 2 : 5)
                    .overlay(Capsule().strokeBorder(VeyraFrame.resting, lineWidth: compact ? 1 : 1.5))
            }
        }
        .padding(.vertical, compact ? 6 : 11)
    }
}

// MARK: - Binnenkort (losse kaart)

/// Eén losse kaart voor "Binnenkort", zonder gedeeld kader — gebruikt op tv Home in een
/// horizontale rij direct onder "Verder kijken".
struct VeyraBentoUpcomingCardContent: View {
    let item: UpcomingItem
    let now: Date
    let isReminded: Bool
    var compact = false
    var cornerRadius: CGFloat = 22

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            ZStack {
                VeyraArt(url: item.backdropURL, seed: item.title)
                LinearGradient(colors: [.black.opacity(0.55), .clear],
                               startPoint: .bottom, endPoint: .top)
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer(minLength: 0)
                        Image(systemName: isReminded ? "bell.fill" : "bell")
                            .font(compact ? .caption : .callout)
                            .foregroundStyle(isReminded ? VeyraHomeStyle.cyan : .white.opacity(0.85))
                            .padding(compact ? 7 : 10)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    Spacer(minLength: 0)
                    Text(item.episodeCode ?? (item.kind == .movie ? "Film" : "Nieuw"))
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .padding(compact ? 10 : 14)
            }
            // Het cyaan/rode kader zit alleen rond de banner, niet rond de tekst eronder.
            .clipShape(shape)
            .overlay(shape.strokeBorder(isFocused ? VeyraFrame.active : VeyraFrame.resting,
                                        lineWidth: isFocused ? 3 : 1.5))
            .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.32) : Color.black.opacity(0.3),
                    radius: isFocused ? 22 : 14, x: isFocused ? -5 : 0, y: isFocused ? 3 : 10)
            .shadow(color: isFocused ? VeyraColors.red.opacity(0.20) : .clear, radius: 22, x: 8, y: 3)

            // Titel-clearlogo en datum staan samen onder het beeldkader.
            HStack(alignment: .center, spacing: compact ? 8 : 14) {
                VeyraTitleLogo(title: item.title, logoURL: item.logoURL,
                               size: compact ? 15 : 20, maxLogoHeight: compact ? 26 : 38)

                Text(VeyraHomeFormat.when(item.airDate, now: now, dateOnly: true))
                    .font(.system(size: compact ? 14 : 18, weight: .bold))
                    .foregroundStyle(VeyraHomeStyle.cyan)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, compact ? 10 : 14)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(VeyraHomeFormat.when(item.airDate, now: now, dateOnly: true))")
    }
}

// MARK: - Tijd voor jou

struct VeyraBentoTimeContent: View {
    let minutes: Int
    let suggestions: [BentoTimeSuggestion]
    var compact = false

    var body: some View {
        VeyraBentoPanel(compact: compact) {
            VStack(alignment: .leading, spacing: compact ? 6 : 12) {
                VeyraBentoLabel(title: "Tijd voor jou", compact: compact)
                Text("±\(minutes) min")
                    .font(.system(size: compact ? 30 : 76, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                VStack(alignment: .leading, spacing: compact ? 4 : 10) {
                    ForEach(suggestions) { suggestion in pill(suggestion) }
                    if suggestions.isEmpty {
                        Text("Niets past precies in deze tijd. Kies iets uit Verder kijken of Live nu.")
                            .font(compact ? .caption : .callout)
                            .foregroundStyle(VeyraHomeStyle.dim)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func pill(_ suggestion: BentoTimeSuggestion) -> some View {
        HStack(spacing: compact ? 6 : 12) {
            Image(systemName: "play.fill")
                .font(compact ? .caption2 : .callout)
                .foregroundStyle(VeyraHomeStyle.cyan)
            Text("\(suggestion.title) · \(suggestion.detail) · \(suggestion.minutes) min")
                .font(compact ? .caption.weight(.semibold) : .title3.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 10 : 20)
        .padding(.vertical, compact ? 4 : 9)
        .background(Color.white.opacity(0.09), in: Capsule())
    }
}

// MARK: - Nieuw toegevoegd

struct VeyraBentoNewContent: View {
    let items: [BentoNewItem]
    var compact = false

    var body: some View {
        VeyraBentoPanel(compact: compact) {
            VStack(alignment: .leading, spacing: compact ? 8 : 16) {
                VeyraBentoLabel(title: "Nieuw toegevoegd", trailing: "Alles bekijken", compact: compact)
                GeometryReader { geo in
                    let posterHeight = geo.size.height
                    let posterWidth = posterHeight * 2 / 3
                    let gap: CGFloat = compact ? 10 : 20
                    let fit = max(1, Int((geo.size.width + gap) / (posterWidth + gap)))
                    HStack(spacing: gap) {
                        ForEach(items.prefix(fit)) { item in
                            poster(item).frame(width: posterWidth, height: posterHeight)
                        }
                    }
                }
            }
        }
    }

    private func poster(_ item: BentoNewItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            VeyraArt(url: item.posterURL, seed: item.title)
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: UnitPoint(x: 0.5, y: 0.4), endPoint: .bottom)
            Text(item.title)
                .font(.system(size: compact ? 11 : 19, weight: .bold))
                .tracking(compact ? 0.8 : 1.8)
                .textCase(.uppercase)
                .lineLimit(2)
                .padding(compact ? 8 : 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
    }
}

// MARK: - IPTV nieuw toegevoegd (films / series)

/// Poster (2:3, vaste maat) met de titel eronder. Ontbreekt de afbeelding (of laadt hij niet), dan wordt via TMDB
/// een poster gezocht op titel (alleen als `kind` is opgegeven).
struct VeyraBentoPosterContent: View {
    let title: String
    let url: URL?
    var compact = false
    var kind: MediaKind? = nil
    var posterHeight: CGFloat? = nil
    var titleSize: CGFloat? = nil
    /// Poster vult de beschikbare breedte (2:3), voor rasters met vaste kolommen.
    var fillWidth = false
    /// TMDB-id + soort om het "bekeken"-vinkje (Trakt) te tonen.
    var watchedID: Int? = nil
    var watchedKind: MediaKind = .movie
    /// Naam van de bron (addon/mediaserver/IPTV-provider), alleen getoond
    /// als dit item niet aan TMDB gekoppeld kon worden — zie `VeyraPosterCard`.
    var sourceLabel: String? = nil

    @State private var fallbackURL: URL?
    @State private var failed = false

    private var height: CGFloat { posterHeight ?? (compact ? 165 : 260) }
    private var width: CGFloat { height * 2 / 3 }
    private var titleFontSize: CGFloat { titleSize ?? (compact ? 10 : 17) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            ZStack {
                VeyraArt(url: nil, seed: title)
                if let shown = fallbackURL ?? VeyraPosterURL.optimized(url) {
                    AsyncImage(url: shown) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        case .failure: Color.clear.onAppear { failed = true }
                        default: Color.clear
                        }
                    }
                }
            }
            .modifier(PosterBoxModifier(fill: fillWidth, width: width, height: height))
            .clipped()
            .overlay(alignment: .topLeading) {
                if let sourceLabel {
                    Text(sourceLabel.uppercased())
                        .font(.system(size: compact ? 8 : 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, compact ? 5 : 7)
                        .padding(.vertical, compact ? 2 : 3)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(compact ? 6 : 12)
                        .frame(maxWidth: width - (compact ? 12 : 24), alignment: .leading)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let watchedID {
                    // Enkel het vinkje i.p.v. de tekstbadge -- de tekst "Bekeken" nam op de
                    // smalle plankkaarten te veel ruimte in.
                    VeyraWatchedCheckmark(target: watchedKind == .movie ? .movie(TraktIDs(tmdb: watchedID)) : .show(TraktIDs(tmdb: watchedID)),
                                          partialDisplay: .hidden)
                        .padding(compact ? 6 : 12)
                        .scaleEffect(compact ? 0.75 : 1, anchor: .topTrailing)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))

            Text(title)
                .font(.system(size: titleFontSize, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .modifier(PosterTitleBoxModifier(fill: fillWidth, width: width, height: titleFontSize * 2.7))
        }
        // Zonder deze twee: in een grid (`fillWidth`) rekte de poster-
        // afbeelding zelf wel over de volle kolombreedte uit, maar bleef de
        // VStack eromheen (en dus de knop-hittest-zone erbuiten om) op de
        // intrinsieke breedte van de tekst staan -- links uitgelijnd. Alleen
        // het uiterste linkerstuk van de kaart was dan nog aantikbaar.
        .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)
        .contentShape(Rectangle())
        .task(id: "\(title)|\(url == nil || failed)") {
            guard let kind, (url == nil || failed), fallbackURL == nil else { return }
            fallbackURL = await VeyraPosterSearch.posterURL(title: title, kind: kind)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

private struct PosterBoxModifier: ViewModifier {
    let fill: Bool
    let width: CGFloat
    let height: CGFloat

    func body(content: Content) -> some View {
        if fill {
            // Maat komt van een lege kleur (2:3 op de kolombreedte); de afbeelding ligt er als
            // overlay op en kan de kolom dus nooit breder rekken.
            Color.clear
                .frame(maxWidth: .infinity)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay { content }
        } else {
            content.frame(width: width, height: height)
        }
    }
}

private struct PosterTitleBoxModifier: ViewModifier {
    let fill: Bool
    let width: CGFloat
    let height: CGFloat

    func body(content: Content) -> some View {
        if fill {
            content.frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        } else {
            content.frame(width: width, height: height, alignment: .topLeading)
        }
    }
}

/// Kader met kop en een horizontale rij posters; de posters (elk een eigen knop) komen van het scherm.
struct VeyraBentoShelf<Cards: View>: View {
    let title: String
    var subtitle: String? = nil
    var compact = false
    var contentHeight: CGFloat? = nil
    @ViewBuilder var cards: Cards

    var body: some View {
        VeyraBentoPanel(compact: compact) {
            VStack(alignment: .leading, spacing: compact ? 6 : 10) {
                VeyraBentoLabel(title: title, trailing: subtitle, compact: compact, smallTrailing: true)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: compact ? 14 : 26) { cards }
                        .frame(height: contentHeight ?? (compact ? 200 : 312))
                        .padding(.vertical, compact ? 2 : 8)
                        .padding(.horizontal, compact ? 2 : 8)
                }
                .scrollClipDisabled()
                Spacer(minLength: 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 22 : 30, style: .continuous))
        .veyraGlassSurface(cornerRadius: compact ? 22 : 30)
    }
}

// MARK: - Bronnen

struct VeyraBentoSourcesContent: View {
    let sources: [BentoSource]
    var compact = false

    private var good: Int { sources.filter { $0.health == .good }.count }
    private var degraded: Int { sources.filter { $0.health == .degraded }.count }
    private var down: Int { sources.filter { $0.health == .down }.count }

    private var verdict: (text: String, tint: Color) {
        if down > 0 { return ("\(down) offline", VeyraHomeStyle.dim) }
        if degraded > 0 { return ("\(degraded) traag", SourceHealth.degraded.sportTint) }
        return ("stabiel", SourceHealth.good.sportTint)
    }

    var body: some View {
        VeyraBentoPanel(compact: compact) {
            VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                VeyraBentoLabel(title: "Bronnen", compact: compact)
                Text("\(good)/\(sources.count)")
                    .font(.system(size: compact ? 28 : 64, weight: .bold))
                    .monospacedDigit()
                Text(verdict.text)
                    .font(.system(size: compact ? 13 : 24, weight: .semibold))
                    .foregroundStyle(verdict.tint)
                    .padding(.bottom, compact ? 2 : 8)
                if compact {
                    HStack(spacing: 6) {
                        ForEach(sources.prefix(4)) { source in
                            Circle().fill(source.health.sportTint).frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 2)
                } else {
                    ForEach(sources.prefix(3)) { source in
                        HStack(spacing: 12) {
                            Circle().fill(source.health.sportTint).frame(width: 10, height: 10)
                            Text(source.name)
                                .font(.title3)
                                .foregroundStyle(VeyraHomeStyle.dim)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bronnen: \(good) van \(sources.count) stabiel")
    }
}

// MARK: - Streamingdiensten

/// Eén streamingdienst als breed kader: wit woordmerk op de merkkleur (of het vierkante logo met naam als het woordmerk ontbreekt).
struct VeyraBentoStreamingContent: View {
    let name: String
    let iconURL: URL?
    let wideURL: URL?
    let brand: UInt32?
    var compact = false
    /// Eigen logo van de gebruiker: getoond zoals het is.
    var customURL: URL? = nil

    private var tint: Color {
        guard let brand else { return VeyraColors.cyan.opacity(0.35) }
        return Color(red: Double((brand >> 16) & 0xFF) / 255,
                     green: Double((brand >> 8) & 0xFF) / 255,
                     blue: Double(brand & 0xFF) / 255)
    }

    var body: some View {
        let radius: CGFloat = compact ? 16 : 26
        ZStack {
            LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
            content
                .padding(compact ? 12 : 26)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            if compact {
                RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(VeyraFrame.resting, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }

    @ViewBuilder
    private var content: some View {
        if let customURL {
            AsyncImage(url: customURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    nameLabel
                }
            }
        } else if let wideURL {
            AsyncImage(url: wideURL) { phase in
                if let image = phase.image {
                    image.renderingMode(.template).resizable().scaledToFit().foregroundStyle(.white)
                } else {
                    nameLabel
                }
            }
        } else {
            HStack(spacing: compact ? 8 : 14) {
                if let iconURL {
                    AsyncImage(url: iconURL) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Color.white.opacity(0.1) }
                    }
                    .frame(width: compact ? 34 : 64, height: compact ? 34 : 64)
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 14, style: .continuous))
                }
                nameLabel
            }
        }
    }

    private var nameLabel: some View {
        Text(name)
            .font(.system(size: compact ? 14 : 26, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Filmcollecties

/// Landscape kaart voor een filmcollectie: beeld met de naam linksonder.
struct VeyraBentoLandscapeContent: View {
    let title: String
    let url: URL?
    var compact = false

    private var width: CGFloat { compact ? 224 : 380 }
    private var height: CGFloat { compact ? 126 : 214 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VeyraArt(url: nil, seed: title)
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Color.clear }
                }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: UnitPoint(x: 0.5, y: 0.35), endPoint: .bottom)
            Text(title)
                .font(.system(size: compact ? 15 : 26, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(compact ? 10 : 18)
        }
        .frame(width: width, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

/// Kleine landscape balk voor een filmcollectie (zelfde stijl als de kleine "Verder kijken"-balken):
/// het beeld vult de balk, de naam staat er klein linksonder overheen. Vult de maat die de aanroeper geeft.
struct VeyraBentoCollectionMiniContent: View {
    let title: String
    let url: URL?
    var compact = false
    /// Naam onder de banner (Instellingen → Home → Filmcollecties).
    var showName = true
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 8) {
            banner
            if showName {
            Text(title)
                .font(.system(size: compact ? 12 : 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .padding(.horizontal, compact ? 4 : 6)
                .frame(height: compact ? 17 : 26, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    // Kleur bepaalt de maat (het kader van de aanroeper); het beeld ligt er als overlay op,
    // zodat een breed backdrop-beeld de banner niet breder maakt en over de buren heen loopt.
    private var banner: some View {
        Color.white.opacity(0.05)
            .overlay {
                // Het kader (deze hele Color-laag) blijft de maat van de aanroeper; de afbeelding zelf
                // krijgt wat marge zodat ze iets kleiner dan het kader oogt in plaats van het strak te vullen.
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Color.clear }
                    }
                    .padding(compact ? 3 : 5)
                } else {
                    VeyraArt(url: nil, seed: title)
                        .padding(compact ? 3 : 5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: compact ? 16 : 22, style: .continuous))
            // Cyaan-rode rand enkel om de banner (net als bij "Verder kijken"); de naam eronder blijft erbuiten.
            .overlay {
                // Rand (en focus-gloed op tvOS) enkel om de banner; de naam eronder blijft erbuiten.
                RoundedRectangle(cornerRadius: compact ? 16 : 22, style: .continuous)
                    .strokeBorder(isFocused ? VeyraFrame.active : VeyraFrame.resting, lineWidth: isFocused ? 3 : 1.5)
            }
            .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.35) : .clear, radius: 16, x: -4)
            .shadow(color: isFocused ? VeyraColors.red.opacity(0.22) : .clear, radius: 16, x: 6)
    }
}
