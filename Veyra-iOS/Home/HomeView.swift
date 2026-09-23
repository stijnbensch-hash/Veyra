import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedMovieItem: MediaItem?
    @State private var isOpeningMovie = false
    @State private var heroSelection: Int?

    private let posterBaseURL = URL(string: "https://image.tmdb.org/t/p/w500")!

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !viewModel.featuredMovies.isEmpty {
                            heroCarousel
                        }

                        ContinueWatchingRow()
                        TraktUpcomingRow()
                        RecentLiveTVRow()
                        SportsHomeRow()
                        IPTVHomeSeriesRow()
                        IPTVHomeFilmsRow()
                        JellyfinHomeRow()

                        ShelvesHomeSection()

                        if !viewModel.featuredMovies.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                VeyraSectionHeader(title: "Populaire films", subtitle: "Voor jou geselecteerd")
                                    .padding(.horizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(viewModel.featuredMovies) { movie in
                                            Button {
                                                Task { await openMovie(movie) }
                                            } label: {
                                                VeyraPosterCard(
                                                    title: movie.title,
                                                    url: posterURL(for: movie),
                                                    width: 130,
                                                    genre: TMDBGenreNames.firstMovieName(for: movie.genreIDs ?? []),
                                                    rating: movie.voteAverage
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(isOpeningMovie)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        } else if viewModel.isLoading {
                            ProgressView("Home laden…")
                                .padding(.top, 60)
                        } else if let errorMessage = viewModel.errorMessage {
                            VStack(spacing: 12) {
                                Text("Home kon niet worden geladen")
                                    .font(.headline)
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button("Opnieuw proberen") {
                                    Task { await viewModel.loadFeaturedMovies() }
                                }
                            }
                            .padding(.top, 60)
                            .padding(.horizontal)
                        } else {
                            ContentUnavailableView(
                                "Geen content beschikbaar",
                                systemImage: "house"
                            )
                            .padding(.top, 40)
                        }
                    }
                    .padding(.vertical)
                }

                if isOpeningMovie {
                    ProgressView("Film openen…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await viewModel.loadFeaturedMoviesIfNeeded() }
            .navigationDestination(item: $selectedMovieItem) { movie in
                MovieDetailView(movie: movie)
            }
            .onChange(of: selectedMovieItem) { _, newValue in
                // Meldt deze push aan bij de gedeelde Home-navigatiestatus
                // zodat de zwevende zoek-/instellingenknoppen verdwijnen
                // zolang deze titel geopend staat.
                HomeNavigationState.shared.setActive(newValue != nil, source: "homeHero")
            }
        }
    }

    private var heroMovies: [TMDBMovie] {
        Array(viewModel.featuredMovies.prefix(10))
    }

    private var heroCarousel: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(heroMovies) { movie in
                        Button {
                            Task { await openMovie(movie) }
                        } label: {
                            heroPoster(movie)
                        }
                        .buttonStyle(.plain)
                        .disabled(isOpeningMovie)
                        .containerRelativeFrame(.horizontal)
                        .id(movie.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $heroSelection)
            .frame(height: 480)

            if let selected = heroMovies.first(where: { $0.id == heroSelection }) ?? heroMovies.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selected.title)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)

                    if let year = releaseYear(selected) {
                        Text(year)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .animation(.easeInOut(duration: 0.2), value: heroSelection)
            }
        }
    }

    /// Vult de volledige breedte van het scherm (geen omringende marge)
    /// zodat de carousel als een echte, schermvullende hero-banner aanvoelt
    /// in plaats van een rij kaarten. Alleen de onderkant is afgerond, als
    /// overgang naar de rest van Home.
    private func heroPoster(_ movie: TMDBMovie) -> some View {
        AsyncImage(url: posterURL(for: movie)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    VeyraColors.surface
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
        }
        // Alleen de onderkant afronden — de bovenkant valt toch al samen
        // met de rand van het scherm (achter de status balk).
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28
            )
        )
    }

    private func releaseYear(_ movie: TMDBMovie) -> String? {
        guard let date = movie.releaseDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    private func posterURL(for movie: TMDBMovie) -> URL? {
        guard let path = movie.posterPath else { return nil }
        return posterBaseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    @MainActor
    private func openMovie(_ movie: TMDBMovie) async {
        guard !isOpeningMovie else { return }
        isOpeningMovie = true
        defer { isOpeningMovie = false }

        guard let service = TMDBService() else { return }
        if let item = try? await service.mediaItem(for: movie) {
            selectedMovieItem = item
        }
    }
}
