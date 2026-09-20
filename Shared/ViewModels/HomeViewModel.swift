import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var featuredMovies: [TMDBMovie] = []
    @Published private(set) var featuredSeries: [TMDBSeries] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    nonisolated init() {}

    func loadFeaturedMoviesIfNeeded() async {
        guard featuredMovies.isEmpty else { return }
        await loadFeaturedMovies()
    }

    func loadFeaturedMovies() async {
        isLoading = true
        errorMessage = nil

        guard let service = TMDBService() else {
            errorMessage = "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }

        do {
            let result = try await service.popularMovies()
            try Task.checkCancellation()
            featuredMovies = result
        } catch {
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadFeaturedSeriesIfNeeded() async {
        guard featuredSeries.isEmpty else { return }
        await loadFeaturedSeries()
    }

    func loadFeaturedSeries() async {
        guard let service = SeriesService() else { return }

        do {
            let result = try await service.popularSeries()
            try Task.checkCancellation()
            featuredSeries = result
        } catch {
            // Serie-fouten mogen de bestaande films-hero niet blokkeren; stil negeren.
        }
    }
}
