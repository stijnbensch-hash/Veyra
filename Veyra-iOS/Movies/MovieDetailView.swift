import SwiftUI

struct MovieDetailView: View {
    let movie: MediaItem

    @State private var ratings = MetadataRatings()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ObservedObject private var traktStore = TraktStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                backdrop

                VStack(alignment: .leading, spacing: 14) {
                    VeyraClearLogo(item: movie, fallbackTitle: movie.title, maxWidth: 320, maxHeight: 80, font: .title.weight(.bold))

                    if let year = releaseYear {
                        Text(year)
                            .font(.subheadline)
                            .foregroundStyle(VeyraColors.cyan)
                    }

                    MetadataRatingsView(ratings: ratings)

                    if let overview = movie.overview, !overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        SourceSelectionView(item: movie)
                    } label: {
                        Label(traktStore.progress(for: movie) != nil ? "Hervatten" : "Afspelen", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VeyraColors.cyan)

                    // Eigen rij voor de secundaire knoppen -- samen met
                    // Afspelen op één rij paste dit niet meer naast elkaar
                    // op smallere iPhones (liep buiten het scherm).
                    HStack(spacing: 10) {
                        TrailerButton(tmdbID: movie.tmdbID, isShow: false, compact: true)
                        WatchedToggleButton(item: movie)
                        FavoriteToggleButton(item: movie, compact: true)
                        WatchlistToggleButton(item: movie, compact: true)
                    }
                }
                .padding(.horizontal)

                CastRow(item: movie)

                SimilarTitlesRow(item: movie)
            }
            .padding(.bottom, 40)
            .veyraReadableWidth()
        }
        .background(VeyraColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { floatingBackButton }
        .ignoresSafeArea(edges: .top)
        .task(id: movie.id) {
            guard let tmdbID = movie.tmdbID else { return }
            ratings = await MetadataRatingsService.movieRatings(tmdbID: tmdbID, imdbID: movie.imdbID)
        }
    }

    private var backdrop: some View {
        // Expliciet breedte EN hoogte geven via GeometryReader -- met enkel
        // een vaste hoogte berekent een resizable/scaledToFill-Image zijn
        // eigen "ideale" breedte uit de beeldverhouding, en die lekt door
        // naar de VStack erboven (die daardoor breder dan het scherm werd
        // en gecentreerd ging overlopen aan beide kanten).
        GeometryReader { geo in
            AsyncImage(url: movie.backdropURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    VeyraColors.surface
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .frame(height: VeyraPosterMetrics(regular: sizeClass == .regular).backdropHeight)
    }

    private var floatingBackButton: some View {
        BackButtonCircle()
            .padding(.leading, 16)
            .padding(.top, 50)
    }

    private var releaseYear: String? {
        guard let date = movie.releaseDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
}
