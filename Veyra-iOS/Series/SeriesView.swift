import SwiftUI

struct SeriesView: View {
    @State private var series: [TMDBSeries] = []
    @State private var selectedSeries: TMDBSeries?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedProvider: WatchProvider?

    @AppStorage("catalog.watchRegion")
    private var watchRegion = "BE"

    @State private var catalogRequestID = UUID()

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]
    private let posterBaseURL = URL(string: "https://image.tmdb.org/t/p/w500")!

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraArtworkBackground(
                    url: series.first?.backdropPath.flatMap {
                        URL(string: "https://image.tmdb.org/t/p/w1280" + $0)
                    }
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        if let featured = series.first {
                            VeyraHero(
                                title: featured.name,
                                eyebrow: "Serie uitgelicht",
                                overview: featured.overview,
                                metadata: featured.firstAirDate.map { [String($0.prefix(4))] } ?? []
                            ) {
                                Button {
                                    selectedSeries = featured
                                } label: {
                                    VeyraActionLabel(title: "Afleveringen bekijken", symbol: "play.rectangle")
                                }
                                .buttonStyle(.plain)
                                .background(.white.opacity(0.14), in: Capsule())
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            header

                            WatchProviderRowIOS(
                                kind: .tv,
                                selection: $selectedProvider,
                                region: $watchRegion
                            )
                        }

                        content
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: watchRegion) { _, _ in selectedProvider = nil }
            .task(id: "\(watchRegion)-\(selectedProvider?.id ?? 0)") { await loadSeries() }
            .navigationDestination(item: $selectedSeries) { series in
                SeriesDetailView(series: series)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VeyraSectionHeader(
            title: "Series",
            subtitle: selectedProvider.map { "\($0.name) · \(watchRegion)" } ?? "Populair · \(watchRegion)"
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading && series.isEmpty {
            ProgressView("Series laden…")
                .padding(.top, 20)
                .frame(maxWidth: .infinity)
        } else if let errorMessage, series.isEmpty {
            errorView(errorMessage)
        } else if series.isEmpty {
            ContentUnavailableView("Geen series beschikbaar", systemImage: "tv")
        } else {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(series) { item in
                    Button {
                        selectedSeries = item
                    } label: {
                        VeyraPosterCard(title: item.name, url: posterURL(for: item), symbol: "tv", width: 150)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("Series konden niet worden geladen")
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Opnieuw proberen") {
                Task { await loadSeries() }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private func posterURL(for series: TMDBSeries) -> URL? {
        guard let path = series.posterPath else { return nil }
        return posterBaseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    // MARK: - Load series

    @MainActor
    private func loadSeries() async {
        let requestID = UUID()
        catalogRequestID = requestID
        isLoading = true
        errorMessage = nil

        guard let service = SeriesService(), let token = AppConfiguration.tmdbReadAccessToken else {
            errorMessage = "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }

        do {
            let result: [TMDBSeries]

            if let selectedProvider {
                result = try await TMDBClient(readAccessToken: token)
                    .series(providerID: selectedProvider.id, region: watchRegion)
            } else {
                result = try await service.popularSeries()
            }

            try Task.checkCancellation()
            guard catalogRequestID == requestID else { return }
            series = result
        } catch {
            guard !Task.isCancelled, catalogRequestID == requestID else { return }
            errorMessage = error.localizedDescription
        }

        if catalogRequestID == requestID {
            isLoading = false
        }
    }
}

#Preview {
    SeriesView()
}
