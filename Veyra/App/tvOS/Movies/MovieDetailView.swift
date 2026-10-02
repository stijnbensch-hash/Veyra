import SwiftUI

struct MovieDetailView: View {
    let movie: MediaItem

    @State private var ratings = MetadataRatings()
    @State private var runtimeMinutes: Int?
    // Fase 7 (spec §33): welke officiële TMDB-collectie deze film bevat, indien van toepassing --
    // nooit een hardcoded lijst, enkel wat TMDB's filmdetail meegeeft.
    @State private var belongsToCollection: TMDBBelongsToCollection?
    // Fase 4 (TMDB-spec, append_to_response/progressive enrichment): resultaat van de ÉNE
    // gecombineerde movieDetails-call (credits/videos/reviews erin), zodat CastRow/
    // TrailerSection/ReviewsSection die niet nog eens apart hoeven op te vragen.
    @State private var details: TMDBMovie?
    // Onderscheidt "nog niet geprobeerd" van "geprobeerd, evt. zonder resultaat" -- anders zou
    // de eerste render (details nog nil) ten onrechte als "bevestigd leeg" doorgegeven worden.
    @State private var didLoadDetails = false
    @ObservedObject private var traktStore = TraktStore.shared

    // MARK: - Hero-trailer
    // Geluidloze trailer-voorvertoning achter de hero, zodra de kijker
    // ~2s op de Afspelen-knop rust. `dwellGeneration` annuleert een
    // wachtende taak zodra de focus eerder wegvalt (zelfde patroon als
    // `SubtitleService`'s generation-guard).
    @FocusState private var isPlayFocused: Bool
    @State private var heroTrailerKey: String?
    @State private var showHeroTrailer = false
    @State private var dwellGeneration = UUID()

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                background
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay {
                        if showHeroTrailer, let heroTrailerKey {
                            VeyraTrailerAutoplayView(youtubeKey: heroTrailerKey)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .transition(.opacity)
                        }
                    }
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

                    CastRow(item: movie, preloadedCredits: movie.tmdbID == nil ? .none : (didLoadDetails ? .value(details?.credits) : .pending))
                        .padding(.horizontal, 48)
                        .padding(.top, 12)

                    TrailerSection(item: movie, preloadedTrailer: movie.tmdbID == nil ? .none : (didLoadDetails ? .value(details?.videos?.results.bestTrailer) : .pending))
                        .padding(.horizontal, 48)
                        .padding(.top, 12)

                    ReviewsSection(item: movie, preloadedReviews: movie.tmdbID == nil ? .none : (didLoadDetails ? .value(details?.reviews?.results.withUsableContent ?? []) : .pending))
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
            didLoadDetails = false
            details = nil
            defer { didLoadDetails = true }
            guard let tmdbID = movie.tmdbID else { return }
            // Fase 3+4 (TMDB-spec, duplicate-request cleanup + append_to_response): dit haalde
            // voorheen 3x los hetzelfde filmdetail-eindpunt op (ratings/runtime/collection), en
            // CastRow/TrailerSection/ReviewsSection vroegen daarna ZELF nog eens credits/videos/
            // reviews los op -- nu allemaal in ÉÉN gecombineerde aanvraag.
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
        .onChange(of: isPlayFocused) { _, focused in
            let generation = UUID()
            dwellGeneration = generation
            guard focused else {
                withAnimation(.easeInOut(duration: 0.3)) { showHeroTrailer = false }
                return
            }
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, dwellGeneration == generation else { return }
                if heroTrailerKey == nil {
                    heroTrailerKey = await MetadataTrailerService.trailer(for: movie)?.key
                }
                guard dwellGeneration == generation, heroTrailerKey != nil else { return }
                withAnimation(.easeInOut(duration: 0.6)) { showHeroTrailer = true }
            }
        }
        .onChange(of: movie.id) { _, _ in
            heroTrailerKey = nil
            showHeroTrailer = false
            dwellGeneration = UUID()
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

                    HStack(spacing: 16) {
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

                        // Veyra Pulse: speelduur -- zelfde icoon+pil-taal als elders (Live TV,
                        // Verder kijken). Kwaliteit/bronnen zijn hier bewust nog niet
                        // toegevoegd: die zijn pas bekend na broncontrole, niet vooraf.
                        if let runtimeMinutes, let pulse = VeyraPulseInfo(kind: .movie, text: formattedRuntime(runtimeMinutes)) {
                            VeyraPulseBadge(info: pulse)
                        }
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
                        .focused($isPlayFocused)

                        TraktProgressResetButton(item: movie, compact: true)
                        WatchedToggleButton(item: movie)
                        FavoriteToggleButton(item: movie)
                        WatchlistToggleButton(item: movie)
                        AddToCollectionButton(item: movie)
                        NavigationLink {
                            VeyraArtworkPickerView(item: movie)
                        } label: {
                            VeyraActionLabel(title: "ARTWORK", symbol: "photo.on.rectangle.angled", compact: true)
                        }
                        .buttonStyle(VeyraFocusButtonStyle())
                        if let belongsToCollection {
                            NavigationLink {
                                VeyraCollectionDetailView(source: .official(tmdbCollectionID: belongsToCollection.id, name: belongsToCollection.name))
                            } label: {
                                VeyraActionLabel(title: "COLLECTIE", symbol: "rectangle.stack.fill", compact: true)
                            }
                            .buttonStyle(VeyraFocusButtonStyle())
                        }
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
            VeyraAsyncImage(
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

    // MARK: - Speelduur

    private func formattedRuntime(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)u \(minutes % 60)m" : "\(minutes) min"
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
