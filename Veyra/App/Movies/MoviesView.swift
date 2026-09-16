import SwiftUI

struct MoviesView: View {
    private let movies = [
        MediaItem(title: "Test Movie", type: .movie),
        MediaItem(title: "Veyra Demo", type: .movie),
        MediaItem(title: "Coming Soon", type: .movie)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.04, blue: 0.07),
                    Color(red: 0.02, green: 0.10, blue: 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 40) {
                Text("MOVIES")
                    .font(.system(size: 54, weight: .light))
                    .tracking(12)
                    .foregroundStyle(.white)

                HStack(spacing: 35) {
                    ForEach(movies) { movie in
                        NavigationLink {
                            MovieDetailView(movie: movie)
                        } label: {
                            VStack {
                                Image(systemName: "film")
                                    .font(.system(size: 55))

                                Text(movie.title)
                                    .font(.headline)
                            }
                            .frame(width: 260, height: 170)
                        }
                    }
                }

                Spacer()
            }
            .padding(70)
        }
    }
}

#Preview {
    NavigationStack {
        MoviesView()
    }
}
