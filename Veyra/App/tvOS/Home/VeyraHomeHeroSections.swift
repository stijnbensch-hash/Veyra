import SwiftUI

struct VeyraMovieHero: View {
    let movie: TMDBMovie
    var body: some View {
        VeyraHero(title: movie.title, eyebrow: "Uitgelicht", overview: movie.overview,
                  metadata: movie.releaseDate.map { [String($0.prefix(4))] } ?? []) {
            NavigationLink { VeyraMovieDestination(movie: movie, play: true) } label: {
                VeyraActionLabel(title: "Afspelen", symbol: "play.fill")
            }.buttonStyle(VeyraFocusButtonStyle(primary: true))
            NavigationLink { VeyraMovieDestination(movie: movie, play: false) } label: {
                VeyraActionLabel(title: "Meer informatie", symbol: "info.circle")
            }.buttonStyle(VeyraFocusButtonStyle())
        }
    }
}

/// Alleen-lezen hero voor een item dat momenteel focus heeft in een van de
/// Home-rijen (zie `VeyraHeroSpotlight`). Toont dezelfde titel/overzicht-
/// opmaak als de uitgelichte hero, maar zonder actieknoppen: de gebruiker
/// selecteert het item hieronder in de rij zelf.
struct VeyraSpotlightHero: View {
    let content: VeyraHeroContent

    var body: some View {
        VeyraHero(
            title: content.title,
            eyebrow: content.eyebrow,
            overview: content.overview,
            metadata: content.metadata
        ) {
            EmptyView()
        }
    }
}

extension VeyraHeroContent {
    static func movie(_ movie: TMDBMovie) -> VeyraHeroContent {
        VeyraHeroContent(
            id: "movie:\(movie.id)",
            eyebrow: "Uitgelicht",
            title: movie.title,
            overview: movie.overview,
            metadata: movie.releaseDate.map { [String($0.prefix(4))] } ?? [],
            backdropURL: movie.backdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280" + $0) }
        )
    }

    static func series(_ series: TMDBSeries) -> VeyraHeroContent {
        VeyraHeroContent(
            id: "series:\(series.id)",
            eyebrow: "Serie uitgelicht",
            title: series.name,
            overview: series.overview,
            metadata: series.firstAirDate.map { [String($0.prefix(4))] } ?? [],
            backdropURL: series.backdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280" + $0) }
        )
    }
}

struct VeyraSeriesHero: View {
    let series: TMDBSeries
    var body: some View {
        VeyraHero(title: series.name, eyebrow: "Serie uitgelicht", overview: series.overview,
                  metadata: series.firstAirDate.map { [String($0.prefix(4))] } ?? []) {
            NavigationLink { SeriesDetailView(series: series) } label: {
                VeyraActionLabel(title: "Afleveringen bekijken", symbol: "play.rectangle")
            }.buttonStyle(VeyraFocusButtonStyle(primary: true))
        }
    }
}

/// UI-only adapter to the existing metadata and source/detail routes.
struct VeyraMovieDestination: View {
    let movie: TMDBMovie
    let play: Bool
    @State private var item: MediaItem?
    @State private var error: String?
    @State private var retry = 0
    var body: some View {
        Group {
            if let item {
                if play { SourceSelectionView(item: item) }
                else { MovieDetailView(movie: item) }
            } else if let error {
                VStack(spacing: 24) {
                    Text(error)
                    Button("Opnieuw proberen") { retry += 1 }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(VeyraBackground())
            } else { ProgressView("Film laden…").frame(maxWidth: .infinity, maxHeight: .infinity).background(VeyraBackground()) }
        }
        .task(id: retry) {
            guard item == nil else { return }
            error = nil
            guard let service = TMDBService() else { error = "De metadataservice is niet geconfigureerd."; return }
            do {
                let result = try await service.mediaItem(for: movie)
                try Task.checkCancellation()
                item = result
            } catch {
                if !Task.isCancelled { self.error = "Deze film kon niet worden geladen." }
            }
        }
    }
}
