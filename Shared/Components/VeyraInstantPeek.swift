// VeyraInstantPeek.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// "Instant Peek": lang drukken op een poster (Siri Remote-drukvlak vasthouden op tvOS,
// long-press op iOS/macOS) opent een glazen infokaart in beeld i.p.v. meteen te navigeren --
// titel, beschrijving, genre/beoordeling/jaar, plus Play/Details/Toevoegen. Loslaten/terug
// sluit de kaart weer.
//
// Bewust ALLEEN aan op een poster als de aanroeper `onPlay`/`onOpenDetails` meegeeft aan
// `VeyraPosterCard` -- op schermen die dat (nog) niet doen blijft de bestaande werking
// exact hetzelfde (geen long-press, geen gedrag veranderd).
//
// V1-vereenvoudiging: dit toont de kaart als een cover i.p.v. de poster ter plaatse te laten
// "uitdeinen" (dat vraagt een ZStack op vensterniveau, boven de ScrollView, wat één generiek
// component niet kan bieden zonder aan elk scherm te raken). Visueel wel dezelfde glazen
// mini-detailkaart, met een schaal-animatie bij openen/sluiten.

import SwiftUI

struct VeyraInstantPeekOverlay: ViewModifier {
    let title: String
    let posterURL: URL?
    let backdropURL: URL?
    let genre: String?
    let rating: Double?
    let year: String?
    let tmdbID: Int?
    let isMovie: Bool
    var onPlay: (() -> Void)? = nil
    var onOpenDetails: (() -> Void)? = nil
    /// Op tvOS: wanneer meegegeven, plaatst de aanroeper zelf een "Snel bekijken"-item in zijn
    /// eigen `.contextMenu` (bv. samen met "Markeer als bekeken", zie `traktMarkWatchedMenu`) en
    /// wordt hier GEEN eigen contextmenu/gebaar aangemaakt -- op tvOS is lang drukken het
    /// systeem-contextmenu, en twee losse menu's op dezelfde kaart botsen (de buitenste wint).
    var externalTrigger: Binding<Bool>? = nil

    @State private var internalTrigger = false
    private var isPeeking: Binding<Bool> { externalTrigger ?? $internalTrigger }

    func body(content: Content) -> some View {
        if onPlay == nil && onOpenDetails == nil {
            content
        } else {
            content
#if os(tvOS)
                .modifier(TvOSPeekGestureIfNoExternalTrigger(isPeeking: isPeeking, hasExternalTrigger: externalTrigger != nil))
                .fullScreenCover(isPresented: isPeeking) {
                    VeyraInstantPeekCard(
                        title: title, posterURL: posterURL, backdropURL: backdropURL,
                        genre: genre, rating: rating, year: year, tmdbID: tmdbID, isMovie: isMovie,
                        onPlay: onPlay, onOpenDetails: onOpenDetails,
                        onDismiss: { isPeeking.wrappedValue = false }
                    )
                }
#elseif os(macOS)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in isPeeking.wrappedValue = true }
                )
                .sheet(isPresented: isPeeking) {
                    VeyraInstantPeekCard(
                        title: title, posterURL: posterURL, backdropURL: backdropURL,
                        genre: genre, rating: rating, year: year, tmdbID: tmdbID, isMovie: isMovie,
                        onPlay: onPlay, onOpenDetails: onOpenDetails,
                        onDismiss: { isPeeking.wrappedValue = false }
                    )
                    .frame(minWidth: 640, minHeight: 420)
                }
#else
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in isPeeking.wrappedValue = true }
                )
                .fullScreenCover(isPresented: isPeeking) {
                    VeyraInstantPeekCard(
                        title: title, posterURL: posterURL, backdropURL: backdropURL,
                        genre: genre, rating: rating, year: year, tmdbID: tmdbID, isMovie: isMovie,
                        onPlay: onPlay, onOpenDetails: onOpenDetails,
                        onDismiss: { isPeeking.wrappedValue = false }
                    )
                }
#endif
        }
    }
}

#if os(tvOS)
/// Enkel een eigen contextmenu toevoegen als de aanroeper GEEN externe trigger (en dus geen
/// eigen menu-item) meegaf -- anders krijgt een kaart zonder ander menu (bv. geen Trakt-koppeling)
/// alsnog geen manier om Peek te openen.
private struct TvOSPeekGestureIfNoExternalTrigger: ViewModifier {
    let isPeeking: Binding<Bool>
    let hasExternalTrigger: Bool

    func body(content: Content) -> some View {
        if hasExternalTrigger {
            content
        } else {
            content.contextMenu {
                Button {
                    isPeeking.wrappedValue = true
                } label: {
                    Label("Snel bekijken", systemImage: "eye")
                }
            }
        }
    }
}
#endif

extension View {
    func veyraInstantPeek(
        title: String, posterURL: URL?, backdropURL: URL? = nil,
        genre: String? = nil, rating: Double? = nil, year: String? = nil,
        tmdbID: Int?, isMovie: Bool,
        onPlay: (() -> Void)? = nil, onOpenDetails: (() -> Void)? = nil,
        peekTrigger: Binding<Bool>? = nil
    ) -> some View {
        modifier(VeyraInstantPeekOverlay(
            title: title, posterURL: posterURL, backdropURL: backdropURL,
            genre: genre, rating: rating, year: year, tmdbID: tmdbID, isMovie: isMovie,
            onPlay: onPlay, onOpenDetails: onOpenDetails, externalTrigger: peekTrigger
        ))
    }
}

private struct VeyraInstantPeekCard: View {
    let title: String
    let posterURL: URL?
    let backdropURL: URL?
    let genre: String?
    let rating: Double?
    let year: String?
    let tmdbID: Int?
    let isMovie: Bool
    var onPlay: (() -> Void)?
    var onOpenDetails: (() -> Void)?
    let onDismiss: () -> Void

    @State private var overview: String?
    @State private var isLoadingOverview = true
    @State private var isWatchlisted = false
    @State private var isTogglingWatchlist = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompactLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var contentPadding: CGFloat { isCompactLayout ? 20 : 36 }

    private var mediaItem: MediaItem {
        MediaItem(title: title, type: isMovie ? .movie : .series, tmdbID: tmdbID)
    }

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: isCompactLayout ? 18 : 28) {
                        ZStack(alignment: .bottomLeading) {
                            VeyraArt(url: backdropURL ?? posterURL, seed: title, contentMode: .fill)
                                .frame(width: geometry.size.width, height: heroHeight)
                                .clipped()
                            LinearGradient(
                                colors: [.clear, .clear, VeyraColors.background.opacity(0.55), VeyraColors.background],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(width: geometry.size.width, height: heroHeight)
                            VeyraClearLogo(
                                item: mediaItem,
                                fallbackTitle: title,
                                maxWidth: min(logoWidth, geometry.size.width - 2 * contentPadding),
                                maxHeight: logoHeight,
                                font: .system(size: titleFontSize, weight: .bold, design: .rounded)
                            )
                            .padding(.horizontal, contentPadding)
                            .padding(.bottom, 24)
                            .shadow(color: .black.opacity(0.6), radius: 10)

                            #if !os(tvOS)
                            closeButton
                            #endif
                        }
                        .frame(width: geometry.size.width, height: heroHeight)
                        .clipped()
                        .ignoresSafeArea(edges: .top)

                        VStack(alignment: .leading, spacing: 20) {
                            metadataRow

                            if isLoadingOverview {
                                ProgressView().tint(VeyraColors.cyan)
                            } else if let overview, !overview.isEmpty {
                                Text(overview)
                                    #if os(tvOS)
                                    .font(.system(size: 22))
                                    #else
                                    .font(.body)
                                    #endif
                                    .foregroundStyle(.white.opacity(0.88))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: isCompactLayout ? .infinity : 900, alignment: .leading)
                            }

                            actionButtons
                                .padding(.top, 6)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, contentPadding)
                        .padding(.bottom, 40)
                    }
                    .frame(width: geometry.size.width, alignment: .leading)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        #if os(tvOS)
        .onExitCommand { onDismiss() }
        #endif
        .task(id: tmdbID) { await loadOverview() }
        .task(id: tmdbID) { isWatchlisted = TraktStore.shared.isWatchlisted(mediaItem) }
    }

    @ViewBuilder
    private var metadataRow: some View {
        if isCompactLayout {
            VStack(alignment: .leading, spacing: 8) {
                genreBadge
                ratingBadge
                yearLabel
            }
        } else {
            HStack(spacing: 12) {
                genreBadge
                ratingBadge
                yearLabel
            }
        }
    }

    @ViewBuilder
    private var genreBadge: some View {
        if let genreInfo = VeyraPulseInfo(kind: isMovie ? .movie : .series, text: genre) {
            VeyraPulseBadge(info: genreInfo, compact: isCompactLayout)
        }
    }

    @ViewBuilder
    private var ratingBadge: some View {
        if rating ?? 0 > 0,
           let ratingInfo = VeyraPulseInfo(
               kind: isMovie ? .movie : .series,
               text: rating.map { String(format: "★ %.1f", $0) }
           ) {
            VeyraPulseBadge(info: ratingInfo, compact: isCompactLayout)
        }
    }

    @ViewBuilder
    private var yearLabel: some View {
        if let year, !year.isEmpty {
            Text(year)
                .font(isCompactLayout ? .subheadline.bold() : .title3.bold())
                .foregroundStyle(VeyraColors.secondary)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isCompactLayout {
            VStack(alignment: .leading, spacing: 10) {
                playButton
                detailsButton
                watchlistButton
            }
        } else {
            HStack(spacing: 18) {
                playButton
                detailsButton
                watchlistButton
            }
        }
    }

    @ViewBuilder
    private var playButton: some View {
        if let onPlay {
            Button {
                onDismiss()
                onPlay()
            } label: {
                VeyraActionLabel(title: "AFSPELEN", symbol: "play.fill", compact: true)
            }
            .buttonStyle(VeyraGlassButtonStyle(primary: true))
        }
    }

    @ViewBuilder
    private var detailsButton: some View {
        if let onOpenDetails {
            Button {
                onDismiss()
                onOpenDetails()
            } label: {
                VeyraActionLabel(title: "DETAILS", symbol: "info.circle", compact: true)
            }
            .buttonStyle(VeyraGlassButtonStyle())
        }
    }

    private var watchlistButton: some View {
        Button {
            Task { await toggleWatchlist() }
        } label: {
            VeyraActionLabel(
                title: isWatchlisted ? "OP KIJKLIJST" : "TOEVOEGEN",
                symbol: isWatchlisted ? "checkmark" : "plus", compact: true
            )
        }
        .buttonStyle(VeyraGlassButtonStyle())
        .disabled(isTogglingWatchlist || tmdbID == nil)
    }

    private var heroHeight: CGFloat {
        #if os(tvOS)
        420
        #else
        340
        #endif
    }

    private var titleFontSize: CGFloat {
        #if os(tvOS)
        44
        #else
        30
        #endif
    }

    private var logoWidth: CGFloat {
        #if os(tvOS)
        620
        #else
        280
        #endif
    }

    private var logoHeight: CGFloat {
        #if os(tvOS)
        140
        #else
        70
        #endif
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 54)
        .padding(.trailing, 20)
        .frame(maxWidth: .infinity, alignment: .topTrailing)
    }

    private func loadOverview() async {
        isLoadingOverview = true
        defer { isLoadingOverview = false }
        guard let tmdbID, let token = AppConfiguration.tmdbReadAccessToken else { return }
        if isMovie {
            overview = try? await TMDBClient(readAccessToken: token).movieDetails(id: tmdbID).overview
        } else if let service = SeriesService() {
            overview = try? await service.seriesDetails(id: tmdbID).overview
        }
    }

    private func toggleWatchlist() async {
        guard !isTogglingWatchlist else { return }
        isTogglingWatchlist = true
        defer { isTogglingWatchlist = false }
        let target = !isWatchlisted
        do {
            try await TraktStore.shared.setWatchlist(mediaItem, included: target)
            isWatchlisted = target
        } catch {
            // Stil falen: de knop blijft gewoon op de vorige stand staan, geen blokkerende alert
            // voor een korte peek-kaart.
        }
    }
}
