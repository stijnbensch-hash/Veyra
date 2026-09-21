import SwiftUI

struct MovieDetailView: View {
    let movie: MediaItem

    @State private var ratings = MetadataRatings()

    var body: some View {
        ZStack {
            background

            LinearGradient(
                colors: [
                    .black.opacity(0.15),
                    .black.opacity(0.55),
                    Color(red: 0.01, green: 0.04, blue: 0.07)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            HStack(alignment: .center, spacing: 50) {
                VStack(alignment: .leading, spacing: 26) {
                    VeyraWatchedBadge(
                        target: .movie(
                            TraktIDs(
                                imdb: movie.imdbID,
                                tmdb: movie.tmdbID
                            )
                        )
                    )

                    Text(movie.title)
                        .font(
                            .system(
                                size: 54,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                        .lineLimit(2)

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

                    HStack(spacing: 20) {
                        NavigationLink {
                            SourceSelectionView(
                                item: movie
                            )
                        } label: {
                            Label(
                                "AFSPELEN",
                                systemImage: "play.fill"
                            )
                            .font(
                                .system(
                                    size: 22,
                                    weight: .bold
                                )
                            )
                            .padding(
                                .horizontal,
                                12
                            )
                        }

                        WatchlistToggleButton(item: movie)
                    }

                    Spacer()
                }
                .traktMarkWatchedMenu(movie)
                .padding(
                    .top,
                    40
                )
                .frame(maxWidth: 1000, alignment: .leading)

                Spacer(
                    minLength: 0
                )
            }

            // Compactere marge voor tvOS
            .padding(
                .horizontal,
                48
            )
            .padding(
                .top,
                36
            )
            .padding(
                .bottom,
                50
            )
        }
        .task(id: movie.id) {
            guard let tmdbID = movie.tmdbID else { return }
            ratings = await MetadataRatingsService.movieRatings(tmdbID: tmdbID, imdbID: movie.imdbID)
        }
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
                        .ignoresSafeArea()

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
