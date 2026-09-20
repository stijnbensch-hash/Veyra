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

    @AppStorage(PosterEnrichmentDefaults.modeKey)
    private var enrichmentSourceRaw = PosterEnrichmentMode.off.rawValue
    @AppStorage(PosterEnrichmentDefaults.showGenreKey)
    private var showGenre = true
    @AppStorage(PosterEnrichmentDefaults.showRatingKey)
    private var showRating = true

    private var enrichmentSource: PosterEnrichmentMode {
        PosterEnrichmentMode(rawValue: enrichmentSourceRaw) ?? .off
    }

    /// Better Posters is de enige bron die hier al echt iets tekent — RPDB
    /// is een externe dienst zonder integratie (zie Shared/Theme/PosterEnrichmentSettings.swift).
    private var enrichmentText: String? {
        guard enrichmentSource == .betterPosters else { return nil }
        var parts: [String] = []
        if showGenre, let genre { parts.append(genre) }
        if showRating, let rating, rating > 0 { parts.append(String(format: "★ %.1f", rating)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // Op de smalle iOS-postercards (112pt) liep de badge-tekst ("Actie ·
    // ★ 7.8") tegen de rand aan en werd afgekapt met "…" — op tvOS (220pt+)
    // is daar meer dan genoeg ruimte voor. Kleinere badge-tekst, minder
    // opvulling en een schaalfactor lossen dat op zonder de inhoud te
    // moeten inkorten.
#if os(tvOS)
    private var enrichmentFontSize: CGFloat { 14 }
    private var enrichmentHPadding: CGFloat { 8 }
    private var enrichmentVPadding: CGFloat { 5 }
#else
    private var enrichmentFontSize: CGFloat { 9 }
    private var enrichmentHPadding: CGFloat { 6 }
    private var enrichmentVPadding: CGFloat { 3 }
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
            .overlay(alignment: .bottomLeading) {
                if let enrichmentText {
                    Text(enrichmentText)
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
            Text(title).font(.system(size: titleFontSize, weight: .medium)).foregroundStyle(.white)
                .lineLimit(2).frame(height: titleHeight, alignment: .topLeading)
        }.frame(width: width).padding(cardPadding)
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
