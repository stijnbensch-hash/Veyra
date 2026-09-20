import Foundation
import Combine

@MainActor
final class SeriesDetailViewModel: ObservableObject {
    @Published private(set) var details: TMDBSeriesDetails?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let seriesID: Int

    nonisolated init(seriesID: Int) {
        self.seriesID = seriesID
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
    }
}
