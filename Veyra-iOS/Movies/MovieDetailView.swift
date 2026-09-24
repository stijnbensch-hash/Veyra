import SwiftUI

struct MovieDetailView: View {
    let movie: MediaItem

    @State private var ratings = MetadataRatings()
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                backdrop

                VStack(alignment: .leading, spacing: 14) {
                    Text(movie.title)
                        .font(.title.weight(.bold))

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

                    HStack(spacing: 10) {
                        NavigationLink {
                            SourceSelectionView(item: movie)
                        } label: {
                            Label("Afspelen", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VeyraColors.cyan)

                        WatchlistToggleButton(item: movie, compact: true)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 40)
            .veyraReadableWidth()
        }
        .background(VeyraColors.background.ignoresSafeArea())
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .task(id: movie.id) {
            guard let tmdbID = movie.tmdbID else { return }
            ratings = await MetadataRatingsService.movieRatings(tmdbID: tmdbID, imdbID: movie.imdbID)
        }
    }

    private var backdrop: some View {
        AsyncImage(url: movie.backdropURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                VeyraColors.surface
            }
        }
        .frame(height: VeyraPosterMetrics(regular: sizeClass == .regular).backdropHeight)
        .clipped()
    }

    private var releaseYear: String? {
        guard let date = movie.releaseDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
}
