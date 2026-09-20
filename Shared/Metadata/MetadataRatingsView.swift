import SwiftUI

struct MetadataRatingsView: View {
    let ratings:
        MetadataRatings

    var body: some View {
        if ratings.hasVisibleRatings {
            HStack(
                spacing: 24
            ) {
                if MetadataPreferences.showIMDb,
                   let value = ratings.imdb
                {
                    ratingItem(
                        provider: .imdb,
                        value:
                            String(
                                format:
                                    "%.1f",
                                value
                            )
                    )
                }

                if MetadataPreferences.showTMDB,
                   let value = ratings.tmdb
                {
                    ratingItem(
                        provider: .tmdb,
                        value:
                            String(
                                format:
                                    "%.1f",
                                value
                            )
                    )
                }

                if MetadataPreferences.showTomatometer,
                   let value =
                        ratings.tomatometer
                {
                    ratingItem(
                        provider:
                            .tomatometer,
                        value:
                            "\(value)%"
                    )
                }

                if MetadataPreferences.showMetacritic,
                   let value =
                        ratings.metacritic
                {
                    ratingItem(
                        provider:
                            .metacritic,
                        value:
                            "\(value)"
                    )
                }

                if MetadataPreferences.showTrakt,
                   let value =
                        ratings.trakt
                {
                    ratingItem(
                        provider:
                            .trakt,
                        value:
                            String(
                                format:
                                    "%.1f",
                                value
                            )
                    )
                }

                if MetadataPreferences.showPopcornmeter,
                   let value =
                        ratings.popcornmeter
                {
                    ratingItem(
                        provider:
                            .popcornmeter,
                        value:
                            "\(value)%"
                    )
                }
            }
        }
    }

    // MARK: - Rating Item

    private func ratingItem(
        provider:
            MetadataRatingProvider,
        value:
            String
    ) -> some View {
        HStack(
            spacing: 8
        ) {
            providerIcon(
                provider
            )

            Text(
                value
            )
            .font(
                .system(
                    size: 21,
                    weight: .bold,
                    design: .rounded
                )
            )
            .monospacedDigit()
            .foregroundStyle(
                .white
            )
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private func providerIcon(
        _ provider:
            MetadataRatingProvider
    ) -> some View {
        switch provider {
        case .imdb:
            Text(
                "IMDb"
            )
            .font(
                .system(
                    size: 14,
                    weight: .black
                )
            )
            .foregroundStyle(
                .black
            )
            .padding(
                .horizontal,
                7
            )
            .padding(
                .vertical,
                4
            )
            .background(
                Color.yellow,
                in:
                    RoundedRectangle(
                        cornerRadius: 5,
                        style: .continuous
                    )
            )

        case .tmdb:
            Text(
                "TMDB"
            )
            .font(
                .system(
                    size: 14,
                    weight: .bold
                )
            )
            .foregroundStyle(
                .cyan
            )

        case .tomatometer:
            Image(
                systemName:
                    "circle.fill"
            )
            .font(
                .system(
                    size: 18
                )
            )
            .foregroundStyle(
                .red
            )

        case .metacritic:
            Text(
                "M"
            )
            .font(
                .system(
                    size: 16,
                    weight: .black
                )
            )
            .foregroundStyle(
                .black
            )
            .frame(
                width: 26,
                height: 26
            )
            .background(
                Color.yellow,
                in:
                    Circle()
            )

        case .trakt:
            Image(
                systemName:
                    "checkmark.square.fill"
            )
            .font(
                .system(
                    size: 20
                )
            )
            .foregroundStyle(
                .pink
            )

        case .popcornmeter:
            Image(
                systemName:
                    "popcorn.fill"
            )
            .font(
                .system(
                    size: 20
                )
            )
            .foregroundStyle(
                .orange
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        MetadataRatingsView(
            ratings:
                MetadataRatings(
                    imdb: 8.7,
                    tmdb: 8.3,
                    tomatometer: 80,
                    metacritic: 64,
                    trakt: 8.4,
                    popcornmeter: 83
                )
        )
    }
}
