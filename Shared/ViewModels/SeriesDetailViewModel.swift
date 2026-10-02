import Foundation
import Combine

@MainActor
final class SeriesDetailViewModel: ObservableObject {
    @Published private(set) var details: TMDBSeriesDetails?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    /// Fase 3 (TMDB-spec, duplicate-request cleanup): hier gecentraliseerd i.p.v. een losse
    /// `.task(id: series.id)` in elke View die zelf nog eens `seriesDetails` opvraagt enkel om
    /// de TMDB-score mee te geven -- gebruikt gewoon `details.voteAverage` die hier al opgehaald
    /// wordt.
    @Published private(set) var ratings = MetadataRatings()

    private let seriesID: Int
    private let title: String

    nonisolated init(seriesID: Int, title: String) {
        self.seriesID = seriesID
        self.title = title
    }

    func loadDetails() async {
        isLoading = true
        errorMessage = nil

        guard let service = SeriesService() else {
            errorMessage = "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }

        do {
            details = try await service.seriesDetails(id: seriesID)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false

        ratings = await MetadataRatingsService.seriesRatings(
            tmdbID: seriesID, imdbID: nil, title: title, knownTMDBRating: details?.voteAverage
        )
    }
}
