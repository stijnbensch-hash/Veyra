import SwiftUI

struct SeriesView: View {
    @State private var series: [TMDBSeries] = []
    @State private var selectedSeries: TMDBSeries?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedProvider: WatchProvider?
    @AppStorage("catalog.watchRegion") private var watchRegion = "BE"
    @State private var catalogRequestID = UUID()

    private let posterBaseURL = URL(
        string: "https://image.tmdb.org/t/p/w500"
    )!

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(
                        red: 0.01,
                        green: 0.04,
                        blue: 0.07
                    ),
                    Color(
                        red: 0.02,
                        green: 0.10,
                        blue: 0.16
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 20
            ) {
                header
                WatchProviderRow(kind: .tv, selection: $selectedProvider, region: $watchRegion)
                content
            }
            .padding(.horizontal, 70)
            .padding(.vertical, 36)
        }
        .task(id: "\(watchRegion)-\(selectedProvider?.id ?? 0)") {
            await loadPopularSeries()
        }
        .onChange(of: watchRegion) { _, _ in selectedProvider = nil }
        .navigationDestination(
            item: $selectedSeries
        ) { series in
            SeriesDetailView(
                series: series
            )
        }
    }

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("SERIES")
                .font(
                    .system(
                        size: 54,
                        weight: .light
                    )
                )
                .tracking(12)
                .foregroundStyle(.white)

            Text(selectedProvider.map { "\($0.name.uppercased()) · \(watchRegion)" } ?? "POPULAIR")
                .font(.caption)
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Series laden…")
                .font(.title3)

            Spacer()
        } else if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Text(
                    "Series konden niet worden geladen"
                )
                .font(.title2)

                Text(errorMessage)
                    .foregroundStyle(.secondary)
                Button("Opnieuw proberen") { Task { await loadPopularSeries() } }
            }

            Spacer()
        } else if series.isEmpty {
            Text("Geen series beschikbaar")
                .foregroundStyle(.secondary)

            Spacer()
        } else {
            ScrollView(.vertical) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 260, maximum: 260), spacing: 35, alignment: .top)],
                    alignment: .leading,
                    spacing: 34
                ) {
                    ForEach(series) { item in
                        seriesCard(item)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func seriesCard(
        _ item: TMDBSeries
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            Button {
                selectedSeries = item
            } label: {
                poster(for: item)
            }
            .buttonStyle(.card)

            Text(item.name)
                .font(
                    .system(
                        size: 26,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(0.85)
                )
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(
                    width: 260,
                    alignment: .leading
                )
                .frame(
                    minHeight: 64,
                    alignment: .topLeading
                )
        }
        .frame(
            width: 260,
            height: 480,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private func poster(
        for item: TMDBSeries
    ) -> some View {
        AsyncImage(
            url: posterURL(for: item)
        ) { phase in
            switch phase {
            case .empty:
                ZStack {
                    posterPlaceholder
                    ProgressView()
                }

            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()

            case .failure:
                posterPlaceholder

            @unknown default:
                posterPlaceholder
            }
        }
        .frame(
            width: 260,
            height: 390
        )
        .clipped()
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.white.opacity(0.08)

            Image(systemName: "tv")
                .font(.system(size: 55))
                .foregroundStyle(.secondary)
        }
    }

    private func posterURL(
        for series: TMDBSeries
    ) -> URL? {
        guard
            let posterPath = series.posterPath
        else {
            return nil
        }

        return posterBaseURL
            .appendingPathComponent(
                posterPath.trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "/"
                    )
                )
            )
    }

    @MainActor
    private func loadPopularSeries() async {
        let requestID = UUID()
        catalogRequestID = requestID
        isLoading = true
        errorMessage = nil
        series = []
        guard let service = SeriesService(), let token = AppConfiguration.tmdbReadAccessToken else {
            errorMessage = "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }
        do {
            let result: [TMDBSeries]
            if let selectedProvider {
                result = try await TMDBClient(readAccessToken: token).series(providerID: selectedProvider.id, region: watchRegion)
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
        if catalogRequestID == requestID { isLoading = false }
    }
}

#Preview {
    NavigationStack {
        SeriesView()
    }
}
