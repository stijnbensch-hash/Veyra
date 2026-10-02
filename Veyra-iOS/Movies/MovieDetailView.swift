import SwiftUI

struct MovieDetailView: View {
    let movie: MediaItem

    @State private var ratings = MetadataRatings()
    @State private var runtimeMinutes: Int?
    // Fase 7 (spec §33): welke officiële TMDB-collectie deze film bevat, indien van toepassing.
    @State private var belongsToCollection: TMDBBelongsToCollection?
    // Fase 4 (TMDB-spec, append_to_response/progressive enrichment): resultaat van de ÉNE
    // gecombineerde movieDetails-call (credits/videos/reviews erin).
    @State private var details: TMDBMovie?
    // Onderscheidt "nog niet geprobeerd" van "geprobeerd, evt. zonder resultaat".
    @State private var didLoadDetails = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ObservedObject private var traktStore = TraktStore.shared

    // MARK: - Hero-trailer
    // Geluidloze trailer-voorvertoning achter de backdrop, gestart nadat het
    // scherm een kort moment open staat (geen "rust op de knop" zoals bij
    // tvOS-afstandsbediening -- op iOS is er geen focus/hover).
    @State private var heroTrailerKey: String?
    @State private var showHeroTrailer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                backdrop

                VStack(alignment: .leading, spacing: 14) {
                    VeyraClearLogo(item: movie, fallbackTitle: movie.title, maxWidth: 320, maxHeight: 80, font: .title.weight(.bold))

                    HStack(spacing: 12) {
                        if let year = releaseYear {
                            Text(year)
                                .font(.subheadline)
                                .foregroundStyle(VeyraColors.cyan)
                        }

                        // Veyra Pulse: speelduur -- zie tvOS-versie voor de toelichting
                        // waarom kwaliteit/bronnen hier bewust nog ontbreken.
                        if let runtimeMinutes, let pulse = VeyraPulseInfo(kind: .movie, text: formattedRuntime(runtimeMinutes)) {
                            VeyraPulseBadge(info: pulse, compact: true)
                        }
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

                    TraktProgressResetButton(item: movie)

                    // Eigen rij voor de secundaire knoppen -- samen met
                    // Afspelen op één rij paste dit niet meer naast elkaar
                    // op smallere iPhones (liep buiten het scherm).
                    HStack(spacing: 10) {
                        WatchedToggleButton(item: movie)
                        FavoriteToggleButton(item: movie, compact: true)
                        WatchlistToggleButton(item: movie, compact: true)
                        AddToCollectionButton(item: movie, compact: true)
                        NavigationLink {
                            VeyraArtworkPickerView(item: movie)
                        } label: {
                            Label("Artwork", systemImage: "photo.on.rectangle.angled")
                        }
                        .buttonStyle(.bordered)
                        .tint(VeyraColors.cyan)
                        if let belongsToCollection {
                            NavigationLink {
                                VeyraCollectionDetailView(source: .official(tmdbCollectionID: belongsToCollection.id, name: belongsToCollection.name))
                            } label: {
                                Label("Collectie", systemImage: "rectangle.stack.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(VeyraColors.cyan)
                        }
                    }
                }
                .padding(.horizontal)

                CastRow(item: movie, preloadedCredits: movie.tmdbID == nil ? .none : (didLoadDetails ? .value(details?.credits) : .pending))

                TrailerSection(item: movie, preloadedTrailer: movie.tmdbID == nil ? .none : (didLoadDetails ? .value(details?.videos?.results.bestTrailer) : .pending))

                ReviewsSection(item: movie, preloadedReviews: movie.tmdbID == nil ? .none : (didLoadDetails ? .value(details?.reviews?.results.withUsableContent ?? []) : .pending))

                SimilarTitlesRow(item: movie)
            }
            .padding(.bottom, 40)
            .veyraReadableWidth()
        }
        .background(VeyraColors.background.ignoresSafeArea())
        .veyraHideNavigationBar()
        .overlay(alignment: .topLeading) { floatingBackButton }
        .ignoresSafeArea(edges: .top)
        .task(id: movie.id) {
            didLoadDetails = false
            details = nil
            defer { didLoadDetails = true }
            guard let tmdbID = movie.tmdbID else { return }
            // Fase 3+4 (TMDB-spec, duplicate-request cleanup + append_to_response): één
            // gecombineerde movieDetails-call i.p.v. 3 losse (ratings/runtime/collection), plus
            // credits/videos/reviews erin zodat CastRow/TrailerSection/ReviewsSection die niet
            // nog eens apart hoeven op te vragen.
            var loaded: TMDBMovie?
            if let token = AppConfiguration.tmdbReadAccessToken {
                loaded = try? await TMDBClient(readAccessToken: token)
                    .movieDetails(id: tmdbID, append: ["credits", "videos", "reviews"])
            }
            details = loaded
            ratings = await MetadataRatingsService.movieRatings(
                tmdbID: tmdbID, imdbID: movie.imdbID, title: movie.title, knownTMDBRating: loaded?.voteAverage
            )
            runtimeMinutes = loaded?.runtime
            belongsToCollection = loaded?.belongsToCollection
        }
    }

    private var backdrop: some View {
        // Expliciet breedte EN hoogte geven via GeometryReader -- met enkel
        // een vaste hoogte berekent een resizable/scaledToFill-Image zijn
        // eigen "ideale" breedte uit de beeldverhouding, en die lekt door
        // naar de VStack erboven (die daardoor breder dan het scherm werd
        // en gecentreerd ging overlopen aan beide kanten).
        GeometryReader { geo in
            ZStack {
                AsyncImage(url: movie.backdropURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        VeyraColors.surface
                    }
                }
                if showHeroTrailer, let heroTrailerKey {
                    VeyraTrailerAutoplayView(youtubeKey: heroTrailerKey)
                        .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .frame(height: VeyraPosterMetrics(regular: sizeClass == .regular).backdropHeight)
        .task(id: movie.id) {
            heroTrailerKey = nil
            showHeroTrailer = false
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            heroTrailerKey = await MetadataTrailerService.trailer(for: movie)?.key
            guard heroTrailerKey != nil else { return }
            withAnimation(.easeInOut(duration: 0.6)) { showHeroTrailer = true }
        }
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

    private func formattedRuntime(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)u \(minutes % 60)m" : "\(minutes) min"
    }
}
