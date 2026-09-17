import SwiftUI

struct SeriesView: View {
    @State private var series: [TMDBSeries] = []
    @State private var selectedSeries: TMDBSeries?
    @State private var isLoading = true
    @State private var errorMessage: String?

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
                spacing: 32
            ) {
                header
                content
            }
            .padding(70)
        }
        .task {
            await loadPopularSeries()
        }
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

            Text("POPULAIR")
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
            }

            Spacer()
        } else if series.isEmpty {
            Text("Geen series beschikbaar")
                .foregroundStyle(.secondary)

            Spacer()
        } else {
            ScrollView(.horizontal) {
                LazyHStack(
                    alignment: .top,
                    spacing: 35
                ) {
                    ForEach(series) { item in
                        seriesCard(item)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 10)
            }
            .frame(height: 520)
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
        isLoading = true
        errorMessage = nil

        guard let service = SeriesService() else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }

        do {
            series = try await service.popularSeries()
        } catch {
            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SeriesView()
    }
}
