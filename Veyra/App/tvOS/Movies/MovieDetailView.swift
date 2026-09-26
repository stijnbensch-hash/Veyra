import SwiftUI

struct MovieDetailView: View {
    let movie: MediaItem

    @State private var ratings = MetadataRatings()
    @ObservedObject private var traktStore = TraktStore.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                background
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay {
                        ZStack {
                            Color.black.opacity(0.25)
                            LinearGradient(
                                colors: [.black.opacity(0.55), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            LinearGradient(
                                colors: [.black.opacity(0.40), .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.35)
                            )
                        }
                        .allowsHitTesting(false)
                    }

                ScrollView {
                    hero

                    CastRow(item: movie)
                        .padding(.horizontal, 48)
                        .padding(.top, 12)

                    SimilarTitlesRow(item: movie)
                        .padding(.horizontal, 48)
                        .padding(.top, 12)
                        .padding(.bottom, 60)
                }
                .contentMargins(.top, 0, for: .scrollContent)
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .scrollClipDisabled()
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
        .task(id: movie.id) {
            guard let tmdbID = movie.tmdbID else { return }
            ratings = await MetadataRatingsService.movieRatings(tmdbID: tmdbID, imdbID: movie.imdbID)
        }
    }

    // MARK: - Hero

    /// De inhoud bepaalt de hoogte, zodat de rijen onder de knoppen aansluiten.
    private var hero: some View {
        HStack(alignment: .center, spacing: 50) {
                VStack(alignment: .leading, spacing: 26) {
                    VeyraClearLogo(
                        item: movie,
                        fallbackTitle: movie.title,
                        maxWidth: 620,
                        maxHeight: 140,
                        font: .system(size: 54, weight: .bold, design: .rounded)
                    )

                    if let year = releaseYear {
                        Text(year)
                            .font(
                                .system(
                                    size: 32,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(
                                .cyan.opacity(0.85)
                            )
                    }

                    MetadataRatingsView(ratings: ratings)

                    if let overview = movie.overview,
                       !overview
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty
                    {
                        Text(overview)
                            .font(
                                .system(
                                    size: 26,
                                    weight: .regular
                                )
                            )
                            .foregroundStyle(
                                .white.opacity(0.82)
                            )
                            .lineSpacing(7)
                            .lineLimit(7)
                            .frame(
                                maxWidth: 1000,
                                alignment: .leading
                            )

                    } else {
                        Text(
                            "Geen Nederlandse beschrijving beschikbaar."
                        )
                        .font(
                            .system(size: 24)
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    HStack(spacing: 12) {
                        NavigationLink {
                            SourceSelectionView(
                                item: movie
                            )
                        } label: {
                            VeyraActionLabel(
                                title: traktStore.progress(for: movie) != nil ? "HERVATTEN" : "AFSPELEN",
                                symbol: "play.fill",
                                compact: true
                            )
                        }
                        .buttonStyle(VeyraFocusButtonStyle(primary: true))

                        TrailerButton(tmdbID: movie.tmdbID, isShow: false)

                        WatchedToggleButton(item: movie)
                        FavoriteToggleButton(item: movie)
                        WatchlistToggleButton(item: movie)
                    }

                }
                .traktMarkWatchedMenu(movie)
                .frame(maxWidth: 1400, alignment: .leading)

                Spacer(
                    minLength: 0
                )
            }

            .padding(
                .horizontal,
                48
            )
            .padding(
                .top,
                130
            )
            .padding(
                .bottom,
                18
            )
    }

    // MARK: - Background

    @ViewBuilder
    private var background: some View {
        if let backdropURL =
            movie.backdropURL
        {
            AsyncImage(
                url: backdropURL
            ) { phase in
                switch phase {
                case .empty:
                    baseBackground

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    baseBackground

                @unknown default:
                    baseBackground
                }
            }

        } else {
            baseBackground
        }
    }

    private var baseBackground: some View {
        VeyraBackground()
    }

    // MARK: - Release year

    private var releaseYear: String? {
        guard
            let releaseDate =
                movie.releaseDate,
            releaseDate.count >= 4
        else {
            return nil
        }

        return String(
            releaseDate.prefix(4)
        )
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(
            movie:
                MediaItem(
                    title:
                        "Testfilm",
                    type:
                        .movie,
                    imdbID:
                        "tt0000000",
                    overview:
                        "Een voorbeeld van de filmdetailpagina van Veyra.",
                    releaseDate:
                        "2026-09-16"
                )
        )
    }
}
