import SwiftUI

struct SeriesView: View {
    @State private var series: [TMDBSeries] = []
    @State private var selectedSeries: TMDBSeries?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedProvider: WatchProvider?
    @State private var selectedGenreID: Int?
    @State private var selectedDecade: VeyraDecadeFilter?
    @State private var selectedRating: VeyraRatingFilter?

    @AppStorage("catalog.watchRegion")
    private var watchRegion = "BE"

    @State private var catalogRequestID = UUID()

    // Automatisch roterende hero, zoals op Home: elke paar seconden een
    // andere titel uit de populairste series, zolang er geen handmatige
    // focus (heroSpotlight) actief is.
    @State private var heroRotationIndex = 0

    private let posterBaseURL = URL(
        string: "https://image.tmdb.org/t/p/w500"
    )!

    private let railSpacing: CGFloat = 32
    private let gridPosterWidth: CGFloat = 240

    @ObservedObject private var heroSpotlight = VeyraHeroSpotlight.shared

    var body: some View {
        ZStack {
            VeyraArtworkBackground(
                url: heroSpotlight.focused?.backdropURL ?? featured?.backdropPath.flatMap {
                    URL(
                        string:
                            "https://image.tmdb.org/t/p/w1280"
                            + $0
                    )
                }
            )
            .id(heroSpotlight.focused?.id ?? "series-background:\(featured?.id ?? -1)")
            .animation(.easeInOut(duration: 0.35), value: heroSpotlight.focused?.id)
            .animation(.easeInOut(duration: 0.35), value: featured?.id)

            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 28
                ) {
                    if let featured {
                        Group {
                            if let focused = heroSpotlight.focused {
                                VeyraSpotlightHero(content: focused)
                            } else {
                                VeyraSeriesHero(series: featured)
                            }
                        }
                        .id(heroSpotlight.focused?.id ?? "series:\(featured.id)")
                        .frame(
                            minHeight: 390,
                            alignment: .center
                        )
                        .animation(.easeInOut(duration: 0.35), value: heroSpotlight.focused?.id)
                        .animation(.easeInOut(duration: 0.35), value: featured.id)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        header

                        MediaFiltersRow(
                            kind: .tv,
                            selectedGenreID: $selectedGenreID,
                            selectedDecade: $selectedDecade,
                            selectedRating: $selectedRating
                        )
                    }

                    content
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(.horizontal, 28)
                .padding(.top, 36)
                .padding(.bottom, 50)
            }
            .contentMargins(
                .horizontal,
                0,
                for: .scrollContent
            )
            .scrollClipDisabled()
        }
        .task {
            await TraktStore.shared
                .refreshIfNeeded()
        }
        .task(
            id: catalogTaskID
        ) {
            await loadPopularSeries()
        }
        .task(id: heroPool.map(\.id)) {
            await rotateHeroAutomatically()
        }
        .onChange(
            of: watchRegion
        ) { _, _ in
            selectedProvider = nil
        }
        .navigationDestination(
            item: $selectedSeries
        ) { series in
            SeriesDetailView(
                series: series
            )
        }
    }

    // MARK: - Hero rotatie

    private var heroPool: [TMDBSeries] {
        Array(series.prefix(10))
    }

    private var featured: TMDBSeries? {
        guard !heroPool.isEmpty else { return nil }
        return heroPool[heroRotationIndex % heroPool.count]
    }

    private func rotateHeroAutomatically() async {
        heroRotationIndex = 0
        guard heroPool.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            heroRotationIndex = (heroRotationIndex + 1) % heroPool.count
        }
    }

    // MARK: - Header

    private var header: some View {
        VeyraSectionHeader(
            title: "Series",
            subtitle: filterSummary
        )
    }

    private var filterSummary: String {
        var parts: [String] = []

        if let selectedProvider {
            parts.append(selectedProvider.name)
        }

        if let selectedGenreID, let name = TMDBGenreNames.tvName(for: selectedGenreID) {
            parts.append(name)
        }

        if let selectedDecade {
            parts.append(selectedDecade.title)
        }

        if let selectedRating {
            parts.append(selectedRating.title)
        }

        guard !parts.isEmpty else {
            return "Populair · \(watchRegion)"
        }

        parts.append(watchRegion)

        return parts.joined(separator: " · ")
    }

    private var catalogTaskID: String {
        [
            watchRegion,
            selectedProvider?.id.description ?? "-",
            selectedGenreID?.description ?? "-",
            selectedDecade?.id ?? "-",
            selectedRating.map { String($0.rawValue) } ?? "-",
        ]
        .joined(separator: "|")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(
                "Series laden…"
            )
            .font(.title3)

            Spacer()

        } else if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                Text(
                    "Series konden niet worden geladen"
                )
                .font(.title2)

                Text(
                    errorMessage
                )
                .foregroundStyle(
                    .secondary
                )

                Button(
                    "Opnieuw proberen"
                ) {
                    Task {
                        await loadPopularSeries()
                    }
                }
            }

            Spacer()

        } else if series.isEmpty {
            Text(
                "Geen series beschikbaar"
            )
            .foregroundStyle(
                .secondary
            )

            Spacer()

        } else {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: gridPosterWidth, maximum: gridPosterWidth + 40), spacing: railSpacing)
                ],
                spacing: 40
            ) {
                ForEach(series) { item in
                    seriesCard(
                        item,
                        width: gridPosterWidth
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Series card

    private func seriesCard(
        _ item: TMDBSeries,
        width: CGFloat
    ) -> some View {
        Button {
            selectedSeries =
                item

        } label: {
            VeyraPosterCard(
                title: item.name,
                url: posterURL(
                    for: item
                ),
                symbol: "tv",
                width: width,
                genre: TMDBGenreNames.firstTVName(for: item.genreIDs ?? []),
                rating: item.voteAverage,
                year: String(item.firstAirDate?.prefix(4) ?? ""),
                tmdbID: item.id,
                isMovie: false,
                releaseDateRaw: item.firstAirDate,
                watchedTarget: .show(TraktIDs(tmdb: item.id)),
                watchedPartialDisplay: .remaining
            )
        }
        .buttonStyle(
            VeyraPosterFocusStyle(cornerRadius: VeyraRadius.poster)
        )
        .reportsHero(.series(item))
    }

    private func posterURL(
        for series: TMDBSeries
    ) -> URL? {
        guard
            let posterPath =
                series.posterPath
        else {
            return nil
        }

        return posterBaseURL
            .appendingPathComponent(
                posterPath
                    .trimmingCharacters(
                        in:
                            CharacterSet(
                                charactersIn: "/"
                            )
                    )
            )
    }

    // MARK: - Load series

    @MainActor
    private func loadPopularSeries()
        async
    {
        let requestID =
            UUID()

        catalogRequestID =
            requestID

        isLoading =
            true

        errorMessage =
            nil

        series =
            []

        guard
            let service =
                SeriesService(),
            let token =
                AppConfiguration
                    .tmdbReadAccessToken
        else {
            errorMessage =
                "De metadataservice is niet geconfigureerd."

            isLoading =
                false

            return
        }

        do {
            let result:
                [TMDBSeries]

            if selectedProvider != nil
                || selectedGenreID != nil
                || selectedDecade != nil
                || selectedRating != nil
            {
                result =
                    try await TMDBClient(
                        readAccessToken:
                            token
                    )
                    .series(
                        providerID:
                            selectedProvider?.id,
                        region:
                            watchRegion,
                        genreID:
                            selectedGenreID,
                        minimumYear:
                            selectedDecade?.startYear,
                        maximumYear:
                            selectedDecade?.endYear,
                        minimumRating:
                            selectedRating?.rawValue
                    )

            } else {
                result =
                    try await service
                        .popularSeries()
            }

            try Task
                .checkCancellation()

            guard
                catalogRequestID
                    == requestID
            else {
                return
            }

            series =
                result

        } catch {
            guard
                !Task.isCancelled,
                catalogRequestID
                    == requestID
            else {
                return
            }

            errorMessage =
                error.localizedDescription
        }

        if catalogRequestID
            == requestID
        {
            isLoading =
                false
        }
    }
}

#Preview {
    NavigationStack {
        SeriesView()
    }
}
