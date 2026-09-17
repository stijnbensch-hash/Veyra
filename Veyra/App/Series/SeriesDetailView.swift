import SwiftUI

struct SeriesDetailView: View {
    let series: TMDBSeries

    @State private var details: TMDBSeriesDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let imageBaseURL = URL(
        string: "https://image.tmdb.org/t/p/"
    )!

    var body: some View {
        ZStack {
            background

            LinearGradient(
                colors: [
                    .black.opacity(0.15),
                    .black.opacity(0.55),
                    Color(red: 0.01, green: 0.04, blue: 0.07)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            if isLoading {
                ProgressView("Serie laden…")
                    .font(.title3)
            } else if let errorMessage {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Serie kon niet worden geladen")
                        .font(.title2)

                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            } else if let details {
                detailContent(details)
            }
        }
        .task {
            await loadDetails()
        }
    }

    @ViewBuilder
    private func detailContent(
        _ details: TMDBSeriesDetails
    ) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 45) {
                HStack(
                    alignment: .top,
                    spacing: 60
                ) {
                    poster(
                        path: details.posterPath
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 24
                    ) {
                        Text(details.name)
                            .font(
                                .system(
                                    size: 54,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        if let year = releaseYear(
                            from: details.firstAirDate
                        ) {
                            Text(year)
                                .font(.title3)
                                .foregroundStyle(
                                    .cyan.opacity(0.85)
                                )
                        }

                        if !details.overview.isEmpty {
                            Text(details.overview)
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
                                    maxWidth: 900,
                                    alignment: .leading
                                )
                        }

                        Spacer()
                    }
                    .padding(.top, 40)

                    Spacer(minLength: 0)
                }

                seasonsSection(details)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 70)
            .padding(.vertical, 55)
        }
    }

    @ViewBuilder
    private func seasonsSection(
        _ details: TMDBSeriesDetails
    ) -> some View {
        let seasons = details.seasons.filter {
            $0.seasonNumber > 0
        }

        if !seasons.isEmpty {
            VStack(
                alignment: .leading,
                spacing: 20
            ) {
                Text("SEIZOENEN")
                    .font(.caption)
                    .tracking(3)
                    .foregroundStyle(
                        .cyan.opacity(0.75)
                    )

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 30) {
                        ForEach(seasons) { season in
                            NavigationLink {
                                SeasonView(
                                    series: details,
                                    season: season
                                )
                            } label: {
                                seasonCard(season)
                            }
                            .buttonStyle(
                                VeyraSeasonButtonStyle()
                            )
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
    }

    private func seasonCard(
        _ season: TMDBSeason
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            AsyncImage(
                url: imageURL(
                    path: season.posterPath,
                    size: "w500"
                )
            ) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        seasonPlaceholder
                        ProgressView()
                    }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    seasonPlaceholder

                @unknown default:
                    seasonPlaceholder
                }
            }
            .frame(
                width: 220,
                height: 330
            )
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18
                )
            )

            Text("Seizoen \(season.seasonNumber)")
                .font(
                    .system(
                        size: 26,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(0.85)
                )
                .lineLimit(1)

            Text(
                "\(season.episodeCount) afleveringen"
            )
            .font(
                .system(
                    size: 20,
                    weight: .regular
                )
            )
            .foregroundStyle(
                .white.opacity(0.65)
            )
        }
        .frame(
            width: 220,
            alignment: .leading
        )
    }

    @ViewBuilder
    private func poster(
        path: String?
    ) -> some View {
        AsyncImage(
            url: imageURL(
                path: path,
                size: "w500"
            )
        ) { phase in
            switch phase {
            case .empty:
                posterPlaceholder
                    .overlay {
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
            width: 330,
            height: 495
        )
        .clipped()
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    @ViewBuilder
    private var background: some View {
        if let backdropURL = imageURL(
            path: details?.backdropPath ?? series.backdropPath,
            size: "w1280"
        ) {
            AsyncImage(url: backdropURL) { phase in
                switch phase {
                case .empty:
                    baseBackground

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()

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
        LinearGradient(
            colors: [
                Color(red: 0.01, green: 0.04, blue: 0.07),
                Color(red: 0.02, green: 0.10, blue: 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.white.opacity(0.08)

            Image(systemName: "tv")
                .font(.system(size: 100))
                .foregroundStyle(
                    .white.opacity(0.45)
                )
        }
    }

    private var seasonPlaceholder: some View {
        ZStack {
            Color.white.opacity(0.08)

            Image(systemName: "tv")
                .font(.system(size: 65))
                .foregroundStyle(
                    .white.opacity(0.35)
                )
        }
    }

    private func imageURL(
        path: String?,
        size: String
    ) -> URL? {
        guard
            let path,
            !path.isEmpty
        else {
            return nil
        }

        return imageBaseURL
            .appendingPathComponent(size)
            .appendingPathComponent(
                path.trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "/"
                    )
                )
            )
    }

    private func releaseYear(
        from date: String?
    ) -> String? {
        guard
            let date,
            date.count >= 4
        else {
            return nil
        }

        return String(date.prefix(4))
    }

    @MainActor
    private func loadDetails() async {
        isLoading = true
        errorMessage = nil

        guard let service = SeriesService() else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."
            isLoading = false
            return
        }

        do {
            details = try await service.seriesDetails(
                id: series.id
            )
        } catch {
            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }
}

private struct VeyraSeasonButtonStyle: ButtonStyle {
    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed ? 0.96 : 1
            )
            .animation(
                .easeOut(duration: 0.15),
                value: configuration.isPressed
            )
    }
}

#Preview {
    NavigationStack {
        SeriesDetailView(
            series: TMDBSeries(
                id: 1399,
                name: "Game of Thrones",
                overview: "Een voorbeeld van een seriedetailpagina.",
                posterPath: nil,
                backdropPath: nil,
                firstAirDate: "2011-04-17",
                voteAverage: 8.4
            )
        )
    }
}
