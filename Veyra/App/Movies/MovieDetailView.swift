import SwiftUI

struct MovieDetailView: View {
    let movie: MediaItem

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

            HStack(alignment: .center, spacing: 60) {
                poster

                VStack(alignment: .leading, spacing: 24) {
                    Text(movie.title)
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if let year = releaseYear {
                        Text(year)
                            .font(.title3)
                            .foregroundStyle(.cyan.opacity(0.85))
                    }

                    if let overview = movie.overview {
                        Text(overview)
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineSpacing(5)
                            .lineLimit(7)
                            .frame(
                                maxWidth: 820,
                                alignment: .leading
                            )
                    }

                    NavigationLink {
                        SourceSelectionView(item: movie)
                    } label: {
                        Label(
                            "PLAY",
                            systemImage: "play.fill"
                        )
                        .font(.system(size: 20, weight: .bold))
                        .padding(.horizontal, 10)
                    }

                    Spacer()
                }
                .padding(.top, 40)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 70)
            .padding(.vertical, 55)
        }
    }

    @ViewBuilder
    private var background: some View {
        if let backdropURL = movie.backdropURL {
            AsyncImage(url: backdropURL) { phase in
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
        LinearGradient(
            colors: [
                Color(red: 0.01, green: 0.04, blue: 0.07),
                Color(red: 0.02, green: 0.10, blue: 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var poster: some View {
        if let posterURL = movie.posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .empty:
                    posterPlaceholder
                        .overlay {
                            ProgressView()
                        }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    posterPlaceholder

                @unknown default:
                    posterPlaceholder
                }
            }
            .frame(width: 330, height: 495)
            .clipped()
            .clipShape(
                RoundedRectangle(cornerRadius: 22)
            )
        } else {
            posterPlaceholder
                .frame(width: 330, height: 495)
                .clipShape(
                    RoundedRectangle(cornerRadius: 22)
                )
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.white.opacity(0.08)

            Image(systemName: "film")
                .font(.system(size: 100))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var releaseYear: String? {
        guard
            let releaseDate = movie.releaseDate,
            releaseDate.count >= 4
        else {
            return nil
        }

        return String(releaseDate.prefix(4))
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(
            movie: MediaItem(
                title: "Test Movie",
                type: .movie,
                imdbID: "tt0000000",
                overview: "A preview of the Veyra movie detail experience.",
                releaseDate: "2026-09-16"
            )
        )
    }
}
