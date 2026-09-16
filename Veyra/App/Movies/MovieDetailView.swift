import SwiftUI

struct MovieDetailView: View {
    let movie: MediaItem

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

            HStack(spacing: 70) {
                Image(systemName: "film")
                    .font(.system(size: 140))
                    .frame(width: 360, height: 500)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 30) {
                    Text(movie.title)
                        .font(.system(size: 54, weight: .semibold))

                    Text("Veyra test movie")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        PlaybackTestView()
                    } label: {
                        Label("PLAY", systemImage: "play.fill")
                            .font(.title3.bold())
                    }

                    Spacer()
                }
                .padding(.top, 40)

                Spacer()
            }
            .padding(70)
        }
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(
            movie: MediaItem(
                title: "Test Movie",
                type: .movie
            )
        )
    }
}
